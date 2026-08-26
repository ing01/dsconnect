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
      ticket: @ticket, user: Current.user,
      # Ignored for ordinary correspondence: the service derives it from the
      # ticket header.
      subject: params[:subject], body: params[:body],
      closing: ActiveModel::Type::Boolean.new.cast(params[:closing])
    ).perform
    render 'show', status: :created
  rescue StandardError => e
    render json: { error: e.message, code: 'delivery_failed' }, status: :unprocessable_entity
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  # Sending to a customer is a mutation of the attendance, so it follows the
  # ticket's own rule rather than being open to anyone who can read it.
  def check_authorization(model = nil)
    super(model || @ticket || Ticket)
  end
end
