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
  #
  # `source_ticket_attachment_id` is the other path in: copying an anexo that
  # already exists on another Ticket (e.g. o pai, quando um Ticket de
  # Desenvolvimento nasce dele) attaches the SAME blob instead of uploading
  # the bytes again.
  def create
    @ticket_attachment = @ticket.ticket_attachments.new(user: Current.user)
    if params[:source_ticket_attachment_id].present?
      source = TicketAttachment.joins(:ticket)
                               .where(tickets: { account_id: Current.account.id })
                               .find(params[:source_ticket_attachment_id])
      @ticket_attachment.file.attach(source.file.blob)
    else
      @ticket_attachment.file.attach(params[:file])
    end
    @ticket_attachment.save!
  end

  def destroy
    @ticket_attachment.destroy!
    head :ok
  end

  # O .zip de todos os anexos do Ticket de uma vez, pro botao "Baixar todos"
  # na aba de Arquivos.
  def download_all
    return head :not_found unless @ticket.ticket_attachments.exists?

    send_data Tickets::Attachments::ZipBuilder.new(ticket: @ticket).render,
              filename: "ticket-#{@ticket.display_id}-anexos.zip",
              type: 'application/zip'
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
