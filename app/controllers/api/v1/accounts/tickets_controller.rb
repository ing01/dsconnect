class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  include TicketActionParams

  DEFAULT_PER_PAGE = 25

  before_action :fetch_ticket, only: [:show, :update, :destroy, :move, :resolve, :reopen, :close, :cancel,
                                      :transfer, :create_child, :set_parent, :merge, :duplicate, :assign_to_me,
                                      :add_sla_hours]
  before_action :check_authorization

  def index
    scope = Current.account.tickets.includes(:team, :ticket_column, :ticket_category, :assignee, :company, :contact, conversations: :contact)
    @tickets = TicketFinder.new(scope: scope, params: params, current_user: Current.user).perform

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
    # Recorded on the creation activity; the Conversation is only linked once the
    # ticket exists, so the origin has to be known before saving.
    @ticket.origin = origin_for_creation
    # A ticket's Mesa (team) is defined by whichever Estagio (ticket_column)
    # it's created into - callers normally send both explicitly (the
    # Kanban/detailed-search UIs always know the selected Mesa), but this
    # keeps `team_id` from being left blank (now mandatory) for any caller
    # that only sends `ticket_column_id`.
    @ticket.team_id ||= @ticket.ticket_column&.team_id
    @ticket.save!

    return if params[:conversation_id].blank?

    link_conversation!(params[:conversation_id])
    # `create` doesn't go through `fetch_ticket`, so the association it just
    # created isn't loaded and the detail partial would render an empty
    # `conversations` array.
    @ticket.reload
  end

  def update
    @ticket.update!(ticket_params.except(:ticket_column_id))
  end

  # Moves the ticket to another column and/or position. Drag-and-drop always
  # sends the drop index; the detail page's Estagio select omits it and lets the
  # server slot the ticket in by ticket number instead.
  def move
    target_column = fetch_ticket_column(params[:ticket_column_id]) || @ticket.ticket_column
    position = params[:position].presence&.to_i || position_by_display_id(target_column)
    @ticket.move_to!(ticket_column: target_column, position: position)
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

  def cancel
    @ticket.cancel!(Current.user, reason: params[:reason])
    render 'show'
  end

  # Moves the ticket between Mesas/Estagios and optionally reassigns status,
  # priority and owner as one auditable operation. See Tickets::TransferService.
  def transfer
    Tickets::TransferService.new(ticket: @ticket, user: Current.user, attributes: transfer_params).perform
    fetch_ticket
    render 'show'
  end

  def create_child
    child = Tickets::ChildBuilder.new(
      parent: @ticket, user: Current.user,
      options: child_options, attributes: child_attributes
    ).perform
    # Reloaded through `fetch_ticket` so the child renders with the detail
    # preloads instead of one query per association.
    fetch_ticket(child.id)
    render 'show', status: :created
  end

  # `belongs_to :parent`, so referencing a new parent replaces the previous
  # reference rather than accumulating. A blank id clears it.
  def set_parent
    parent = params[:parent_id].presence && Current.account.tickets.find(params[:parent_id])
    previous = @ticket.parent
    @ticket.update!(parent: parent)
    log_parent_change(previous, parent)
    fetch_ticket
    render 'show'
  end

  # The ticket being viewed survives; the selected one is closed into it.
  def merge
    source = Current.account.tickets.find(params[:source_id])
    Tickets::MergeService.new(target: @ticket, source: source, user: Current.user).perform
    fetch_ticket
    render 'show'
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def duplicate
    copy = Tickets::DuplicateService.new(ticket: @ticket, user: Current.user).perform
    fetch_ticket(copy.id)
    render 'show', status: :created
  end

  def assign_to_me
    @ticket.update!(assignee: Current.user)
    fetch_ticket
    render 'show'
  end

  def add_sla_hours
    @ticket.extend_due_at!(hours: params[:hours], reason: params[:reason], user: Current.user)
    fetch_ticket
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

  # `show` renders the detail partial, which walks contact, conversations,
  # activities and attachments - without these preloads it fires a query per
  # association per record.
  DETAIL_INCLUDES = [
    :team, :ticket_column, :ticket_category, :assignee, :company, :contact,
    { ticket_attachments: [{ file_attachment: :blob }, :user] },
    { ticket_activities: :user },
    { ticket_conversations: { conversation: [{ contact: :company }, :inbox] } },
    { ticket_followers: :user },
    { ticket_sla_extensions: :user },
    :parent, :children, :merged_into, :merged_tickets
  ].freeze

  def fetch_ticket(id = params[:id])
    @ticket = Current.account.tickets.includes(DETAIL_INCLUDES).find(id)
  end

  def position_by_display_id(target_column)
    Tickets::ColumnPosition.new(ticket: @ticket, column: target_column).by_display_id
  end

  def fetch_ticket_column(id)
    return if id.blank?

    TicketColumn.joins(:team).find_by(id: id, teams: { account_id: Current.account.id })
  end

  # A ticket opened from a chat already knows its customer through the
  # Conversation's Contact, so the Solicitante and the Empresa are inherited
  # instead of being asked for again. Explicitly sent values always win.
  def inherit_customer_from_conversation!(conversation)
    contact = conversation.contact
    return if contact.blank?

    attributes = inherited_customer_attributes(contact)
    @ticket.update!(attributes) if attributes.any?
  end

  def inherited_customer_attributes(contact)
    attributes = {}
    attributes[:company_id] = contact.company_id if @ticket.company_id.blank? && contact.company_id.present?
    # Only when the two agree: a ticket already tagged with one Empresa must not
    # silently gain a requester who belongs to another.
    effective_company = attributes[:company_id] || @ticket.company_id
    attributes[:contact_id] = contact.id if @ticket.contact_id.blank? && contact_matches?(contact, effective_company)
    attributes
  end

  def contact_matches?(contact, company_id)
    company_id.blank? || contact.company_id == company_id
  end

  def link_conversation!(conversation_id)
    conversation = Current.account.conversations.find(conversation_id)
    @ticket.ticket_conversations.create!(conversation: conversation)
    inherit_customer_from_conversation!(conversation)
  end
end
