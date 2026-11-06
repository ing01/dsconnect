# Upload de anexo direto pela API, pra um sistema externo anexar um arquivo
# ao abrir ou atualizar um chamado (ex.: a nota fiscal/XML de um Prazo SEFAZ).
# Mesmo multipart simples que Api::V1::Accounts::TicketAttachmentsController -
# sem `source_ticket_attachment_id` aqui: copiar um anexo de outro ticket e'
# um fluxo so' do painel.
class Api::V1::Integrations::TicketAttachmentsController < Api::V1::Integrations::BaseController
  def index
    @ticket_attachments = ticket.ticket_attachments
                                .includes(file_attachment: :blob)
                                .order(created_at: :desc)
  end

  def create
    @ticket_attachment = ticket.ticket_attachments.new
    @ticket_attachment.file.attach(params[:file])
    @ticket_attachment.save!
  end

  private

  def ticket
    @ticket ||= current_account.tickets.find(params[:ticket_id])
  end
end
