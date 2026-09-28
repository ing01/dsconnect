class Api::V1::Accounts::TicketCustomerCommunicationsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :check_authorization

  def index
    @communications = @ticket.ticket_customer_communications.includes(:user, :contact).order(created_at: :desc)
  end

  # Synchronous, because the caller needs to know whether the message actually
  # went out - closing the ticket depends on it. A failure answers 422 with the
  # reason and the ticket is untouched.
  def create
    if @ticket.customer_email.blank?
      return render json: { error: I18n.t('tickets.communication.no_contact_email'), code: 'contact_email_missing' },
                    status: :unprocessable_entity
    end

    @communication = Tickets::CustomerCommunicationService.new(
      ticket: @ticket, user: Current.user, body: params[:body],
      closing: closing_param, notify_customer: notify_customer_param
    ).perform
    render 'show', status: :created
  rescue StandardError => e
    render json: { error: e.message, code: 'delivery_failed' }, status: :unprocessable_entity
  end

  private

  # Ausente quer dizer correspondencia comum. `cast(nil)` devolve nil, e nil
  # gravado numa coluna NOT NULL atropela o default do banco: a insercao
  # estourava com o erro cru do Postgres na resposta. A tela sempre manda o
  # campo, entao so quem chama a API direto batia nisso.
  def closing_param
    ActiveModel::Type::Boolean.new.cast(params[:closing]) || false
  end

  # Mesmo cuidado do `closing_param`, com o default invertido: ausente quer dizer
  # ENVIAR. Quem chama a API sem conhecer o campo continua recebendo o
  # comportamento de sempre; so um `false` explicito registra sem e-mail.
  def notify_customer_param
    return true unless params.key?(:notify_customer)

    ActiveModel::Type::Boolean.new.cast(params[:notify_customer]) || false
  end

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  # Sending to a customer is a mutation of the attendance, so it follows the
  # ticket's own rule rather than being open to anyone who can read it.
  def check_authorization(model = nil)
    super(model || @ticket || Ticket)
  end
end
