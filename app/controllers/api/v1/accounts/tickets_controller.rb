class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  DEFAULT_PER_PAGE = 25
  # Params that map directly onto an equality filter on `tickets` (used by
  # `filter_by_attributes`, part of the "Busca detalhada" filter set).
  DIRECT_ATTRIBUTE_FILTERS = {
    ticket_column_id: :ticket_column_id,
    team_id: :team_id,
    status: :status,
    priority: :priority,
    display_id: :display_id
  }.freeze

  before_action :fetch_ticket, only: [:show, :update, :destroy, :move, :resolve, :reopen, :close]
  before_action :check_authorization

  def index
    scope = Current.account.tickets.includes(:team, :ticket_column, :assignee, conversations: { contact: :company })
    @tickets = filter_tickets(scope)

    # The Kanban board fetches all tickets of a single column at once (no
    # pagination, keeps drag-and-drop simple); any other listing (e.g. the
    # flat "Lista" view or cross-board queries) is paginated.
    if params[:ticket_column_id].present?
      @tickets = @tickets.order(:position)
      @tickets_count = @tickets.count
      @current_page = 1
    else
      @tickets = @tickets.order(created_at: :desc)
      @tickets_count = @tickets.count
      @current_page = (params[:page] || 1).to_i
      @tickets = @tickets.page(@current_page).per(params[:per_page] || DEFAULT_PER_PAGE)
    end
  end

  def show; end

  # Bootstraps the Kanban for an account that has no Mesa de Servico yet, so a
  # fresh install lands on a usable board instead of an empty screen. Idempotent -
  # see Tickets::DefaultMesaBuilder.
  def ensure_default_mesa
    @team = Tickets::DefaultMesaBuilder.new(account: Current.account).perform
    render 'api/v1/accounts/teams/show', formats: [:json]
  end

  def create
    @ticket = Current.account.tickets.new(ticket_params)
    # A ticket's Mesa (team) is defined by whichever Estagio (ticket_column)
    # it's created into - callers normally send both explicitly (the
    # Kanban/detailed-search UIs always know the selected Mesa), but this
    # keeps `team_id` from being left blank (now mandatory) for any caller
    # that only sends `ticket_column_id`.
    @ticket.team_id ||= @ticket.ticket_column&.team_id
    @ticket.save!

    link_conversation!(params[:conversation_id]) if params[:conversation_id].present?
  end

  def update
    @ticket.update!(ticket_params.except(:ticket_column_id))
  end

  # Moves the ticket to another column and/or position (Kanban drag-and-drop).
  def move
    target_column = fetch_ticket_column(params[:ticket_column_id]) || @ticket.ticket_column
    @ticket.move_to!(ticket_column: target_column, position: params[:position].to_i)
  end

  # The following three are explicit lifecycle-status transitions, distinct
  # from moving between Kanban columns (`move`).
  def resolve
    @ticket.resolve!(Current.user)
    render 'show'
  end

  def reopen
    @ticket.reopen!(Current.user)
    render 'show'
  end

  def close
    @ticket.close!(Current.user)
    render 'show'
  end

  def destroy
    @ticket.destroy!
    head :ok
  end

  private

  # TicketPolicy checks the ticket's assignee/team, so authorization must run
  # against the loaded instance (when there is one) rather than the bare
  # `Ticket` class the generic `check_authorization` would otherwise use.
  def check_authorization(model = nil)
    super(model || @ticket || Ticket)
  end

  def filter_tickets(scope)
    scope = filter_by_ownership(scope)
    scope = filter_by_attributes(scope)
    scope = filter_by_conversation(scope)
    scope = filter_by_contact(scope)
    filter_by_date_and_text(scope)
  end

  def filter_by_ownership(scope)
    return scope.where(assignee_id: Current.user.id) if params[:mine].present?
    return scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?

    scope
  end

  def filter_by_attributes(scope)
    DIRECT_ATTRIBUTE_FILTERS.each do |param, column|
      scope = scope.where(column => params[param]) if params[param].present?
    end
    scope = scope.where('tickets.title ILIKE :q', q: "%#{params[:title]}%") if params[:title].present?
    scope
  end

  def filter_by_conversation(scope)
    return scope if params[:conversation_id].blank?

    scope.joins(:ticket_conversations).where(ticket_conversations: { conversation_id: params[:conversation_id] })
  end

  # Backs the "Busca detalhada" Cliente/Empresa and Solicitante/Contato
  # filters. There's no dedicated ticket->contact FK (a ticket only knows
  # its contact through whichever Conversation(s) are linked to it), so this
  # joins through `ticket_conversations -> conversations -> contact` - the
  # same path `Company#tickets` already relies on.
  CONTACT_FILTER_PARAMS = [:contact_id, :company_id, :contact_query, :company_query].freeze

  def filter_by_contact(scope)
    return scope if CONTACT_FILTER_PARAMS.none? { |param| params[param].present? }

    scope = scope.joins(ticket_conversations: { conversation: :contact })
    scope = filter_by_contact_attributes(scope)
    scope = filter_by_company_query(scope) if params[:company_query].present?
    scope.distinct
  end

  def filter_by_contact_attributes(scope)
    scope = scope.where(contacts: { id: params[:contact_id] }) if params[:contact_id].present?
    scope = scope.where(contacts: { company_id: params[:company_id] }) if params[:company_id].present?
    scope = scope.where('contacts.name ILIKE :q', q: "%#{params[:contact_query]}%") if params[:contact_query].present?
    scope
  end

  def filter_by_company_query(scope)
    scope.joins('INNER JOIN companies ON companies.id = contacts.company_id')
         .where('companies.name ILIKE :q', q: "%#{params[:company_query]}%")
  end

  def filter_by_date_and_text(scope)
    scope = scope.where('tickets.created_at >= ?', params[:created_after].to_date.beginning_of_day) if params[:created_after].present?
    # `created_before` is a plain "YYYY-MM-DD" (a calendar day, e.g. "today"
    # in the Busca detalhada defaults) - comparing with `<=` against that
    # bare date would cast to midnight and silently exclude every ticket
    # created later that same day, so the upper bound is the end of the day.
    scope = scope.where('tickets.created_at <= ?', params[:created_before].to_date.end_of_day) if params[:created_before].present?
    return scope if params[:q].blank?

    scope.where('tickets.title ILIKE :q OR CAST(tickets.display_id AS TEXT) ILIKE :q', q: "%#{params[:q]}%")
  end

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:id])
  end

  def fetch_ticket_column(id)
    return if id.blank?

    TicketColumn.joins(:team).find_by(id: id, teams: { account_id: Current.account.id })
  end

  def link_conversation!(conversation_id)
    conversation = Current.account.conversations.find(conversation_id)
    @ticket.ticket_conversations.create!(conversation: conversation)
  end

  def ticket_params
    params.require(:ticket).permit(:title, :description, :priority, :assignee_id, :team_id, :ticket_column_id)
  end
end
