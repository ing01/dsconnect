# A resposta do cliente, dentro do ticket.
#
# Entra na MESMA conversa que a equipe ja usa (`ticket_customer_communications`),
# com `direction: inbound`. Nao ha thread separada: o que o cliente escreve
# aparece na aba Comunicacao do agente, no lugar onde ele ja olha.
class Api::V1::Client::CommunicationsController < Api::V1::Client::BaseController
  before_action :fetch_ticket

  def create
    return render_empty_message if params[:body].to_s.strip.blank?

    ActiveRecord::Base.transaction do
      @communication = build_communication
      @communication.save!
      attach_uploaded_files!
    end

    # Em segundo plano - quem respondeu nao espera a bandeja do responsavel/
    # seguidores ser escrita para receber o 201.
    Tickets::CustomerCommunicationNotificationJob.perform_later(@communication.id)

    render 'api/v1/client/communications/show', status: :created
  end

  private

  # `fetch_ticket` da base usa `visible_tickets`: responder num ticket de outra
  # empresa nao encontra o ticket, e vira 404.
  def fetch_ticket
    @ticket = visible_tickets.find(params[:ticket_id])
  end

  def build_communication
    @ticket.ticket_customer_communications.new(
      account_id: @ticket.account_id,
      contact: current_contact,
      direction: 'inbound',
      # O assunto e o mesmo cabecalho do ticket que a equipe usa ao escrever -
      # a conversa toda fica sob um titulo so.
      subject: @ticket.display_subject,
      body: params[:body].to_s.strip,
      # Nao ha entrega a fazer: a mensagem ja chegou no instante em que foi
      # gravada. `pending` faria a aba do agente mostrar um envio travado.
      status: 'sent',
      sent_at: Time.current
    )
  end

  def attach_uploaded_files!
    Array(params[:attachments]).reject(&:blank?).each do |arquivo|
      anexo = @ticket.ticket_attachments.new(
        account_id: @ticket.account_id,
        ticket_customer_communication: @communication
      )
      anexo.file.attach(arquivo)
      anexo.save!
    end
  end

  def render_empty_message
    render json: { error: I18n.t('client_area.communication.empty'),
                   code: 'body_required' },
           status: :unprocessable_entity
  end
end
