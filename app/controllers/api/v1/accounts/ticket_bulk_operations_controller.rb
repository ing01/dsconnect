# Painel de tickets em lote (Busca detalhada). Cria a operacao, que roda em
# segundo plano (Tickets::BulkOperationJob), e expoe o andamento e o relatorio.
class Api::V1::Accounts::TicketBulkOperationsController < Api::V1::Accounts::BaseController
  before_action :fetch_operation, only: [:show, :undo, :retry_failed]
  before_action :check_authorization

  # Rede de seguranca pra erro inesperado (bug) - o que ja tem tratamento
  # proprio (RecordInvalid, RecordNotFound, etc) nunca chega aqui, resolvido
  # antes pelo `handle_with_exception` da ApplicationController.
  rescue_from StandardError, with: :render_unexpected_error

  RECENT_LIMIT = 30

  def index
    operations = Current.account.ticket_bulk_operations.includes(:user).order(id: :desc).limit(RECENT_LIMIT)
    render json: { payload: operations.map(&:push_event_data) }
  end

  def show
    render json: @operation.push_event_data.merge(items: @operation.items.order(:id).map(&:push_event_data))
  end

  # Ensaio: diz quantos tickets entram e quantos o usuario nao poderia alterar,
  # sem mudar nada.
  def preview
    tickets = resolve_tickets
    policy_query = Tickets::BulkOperations::Runner::POLICY_QUERY.fetch(action_param, :update?)
    allowed = tickets.count { |ticket| TicketPolicy.new(user_context, ticket).public_send(policy_query) }
    render json: { total: tickets.size, allowed: allowed, forbidden: tickets.size - allowed,
                   finalized: tickets.count(&:finalized?) }
  end

  def create
    tickets = resolve_tickets
    return render_error(I18n.t('tickets.bulk.empty'), 'empty') if tickets.empty?

    operation = build_operation(action_param, operation_params, filters: filters_param)
    operation.save!
    # Um ticket com dado ruim (ex: display_id inconsistente) nao pode
    # derrubar o lote inteiro - sem o rescue, a operacao ja salva ficava
    # com uma fracao dos itens e a tela so' mostrava erro cru. O total
    # reflete so' os itens que realmente entraram.
    tickets.each do |ticket|
      operation.items.create!(ticket_id: ticket.id, display_id: ticket.display_id)
    rescue StandardError => e
      Rails.logger.error("[TicketBulkOperationsController] item do ticket ##{ticket.display_id} falhou: #{e.class} #{e.message}")
    end
    operation.update!(total: operation.items.count)
    Tickets::BulkOperationJob.perform_later(operation.id)
    render json: operation.push_event_data, status: :created
  end

  def undo
    return render_error(I18n.t('tickets.bulk.not_undoable'), 'not_undoable') unless @operation.undoable?

    undo_operation = build_operation(@operation.action, @operation.params.merge('original_action' => @operation.action))
    undo_operation.undo_of_id = @operation.id
    undo_operation.save!
    @operation.items.succeeded.find_each do |item|
      undo_operation.items.create!(ticket_id: item.ticket_id, display_id: item.display_id, before: item.before)
    rescue StandardError => e
      Rails.logger.error("[TicketBulkOperationsController] item de desfazer ##{item.display_id} falhou: #{e.class} #{e.message}")
    end
    undo_operation.update!(total: undo_operation.items.count)
    @operation.update!(undone_at: Time.current)
    Tickets::BulkOperationJob.perform_later(undo_operation.id)
    render json: undo_operation.push_event_data, status: :created
  end

  def retry_failed
    failed = @operation.items.failed
    return render_error(I18n.t('tickets.bulk.empty'), 'empty') if failed.none?

    retry_operation = build_operation(@operation.action, @operation.params, filters: @operation.filters)
    retry_operation.save!
    failed.find_each do |item|
      retry_operation.items.create!(ticket_id: item.ticket_id, display_id: item.display_id)
    rescue StandardError => e
      Rails.logger.error("[TicketBulkOperationsController] item de retentativa ##{item.display_id} falhou: #{e.class} #{e.message}")
    end
    retry_operation.update!(total: retry_operation.items.count)
    Tickets::BulkOperationJob.perform_later(retry_operation.id)
    render json: retry_operation.push_event_data, status: :created
  end

  private

  def check_authorization(model = nil)
    super(model || @operation || TicketBulkOperation)
  end

  def fetch_operation
    @operation = Current.account.ticket_bulk_operations.find(params[:id])
  end

  def build_operation(action, op_params, filters: {})
    Current.account.ticket_bulk_operations.new(user: Current.user, action: action, params: op_params, filters: filters)
  end

  def user_context
    { user: Current.user, account: Current.account, account_user: Current.account_user }
  end

  def action_param
    params[:bulk_action].to_s
  end

  # Texto livre e ids vindos da tela, sem tipos complexos.
  def operation_params
    params.fetch(:operation, {}).permit(
      :priority, :due_date, :scheduled_at, :ticket_category_id, :ticket_complexity_id, :contact_id, :company_id,
      :user_id, :level, :team_id, :ticket_column_id, :body, :resolution, :reason, :service_catalog_item_id,
      :notify_customer, user_ids: []
    ).to_h
  end

  def filters_param
    params.fetch(:filters, {}).permit!.to_h
  end

  # Os tickets escolhidos na tela (ate 200) ou todos do filtro (ate 500).
  def resolve_tickets
    tickets = if params[:ticket_ids].present?
                ids = Array(params[:ticket_ids]).map(&:to_i).uniq
                raise_limit(TicketBulkOperation::SELECTION_LIMIT) if ids.size > TicketBulkOperation::SELECTION_LIMIT
                Current.account.tickets.where(id: ids).to_a
              else
                relation = TicketFinder.new(scope: Current.account.tickets, params: ActionController::Parameters.new(filters_param),
                                            current_user: Current.user).perform
                raise_limit(TicketBulkOperation::FILTER_LIMIT) if relation.count > TicketBulkOperation::FILTER_LIMIT
                relation.distinct.to_a
              end
    exclude_finalized? ? tickets.reject(&:finalized?) : tickets
  end

  # So' a troca de categoria pergunta "tambem nos fechados/cancelados?" na
  # tela (ver TicketBulkPanel.vue) - quem escolhe "so' os abertos" manda este
  # sinalizador, e os ja finalizados saem do escopo antes de criar os itens.
  def exclude_finalized?
    ActiveModel::Type::Boolean.new.cast(params[:exclude_finalized])
  end

  def raise_limit(limit)
    raise ActionController::BadRequest, I18n.t('tickets.bulk.limit_exceeded', limit: limit)
  end

  def render_error(message, code)
    render json: { error: message, code: code }, status: :unprocessable_entity
  end

  def render_unexpected_error(exception)
    Rails.logger.error("[TicketBulkOperationsController] #{exception.class}: #{exception.message}")
    render json: { error: I18n.t('tickets.bulk.unexpected_error', default: 'Não foi possível concluir a operação em lote. Tente novamente ou contate o suporte.') },
           status: :internal_server_error
  end
end
