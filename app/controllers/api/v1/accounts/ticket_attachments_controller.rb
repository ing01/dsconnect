class Api::V1::Accounts::TicketAttachmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :fetch_ticket_attachment, only: [:destroy]
  before_action :check_authorization

  def index
    @ticket_attachments = @ticket.ticket_attachments
                                 .includes(:user, file_attachment: :blob)
                                 .order(created_at: :desc)
  end

  # Takes the file as plain multipart rather than going through the generic
  # /upload blob endpoint: that would need two round-trips (blob then attach)
  # and carries no size guard of its own.
  def create
    @ticket_attachment = @ticket.ticket_attachments.new(user: Current.user)
    @ticket_attachment.file.attach(params[:file])
    @ticket_attachment.save!
  end

  def destroy
    @ticket_attachment.destroy!
    head :ok
  end

  private

  # The policy inspects the uploader, so authorization runs against the loaded
  # record when there is one.
  def check_authorization(model = nil)
    super(model || @ticket_attachment || TicketAttachment)
  end

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def fetch_ticket_attachment
    @ticket_attachment = @ticket.ticket_attachments.find(params[:id])
  end
end
