# As novidades do cliente: o que a equipe escreveu nos chamados dele
# (`ticket_customer_communications`) e o que a equipe respondeu no chat do
# Portal - juntos, do mais recente para o mais antigo.
#
# Continua sem tabela de notificacao propria: as DUAS fontes ja existem, e o
# que muda aqui e' so juntar as duas listas antes de cortar pelo limite.
# Quando houver estado de lido/nao lido, e aqui que ele entra.
class Api::V1::Client::NotificationsController < Api::V1::Client::BaseController
  LIMIT = 50

  def index
    @items = (communication_items + chat_items).sort_by { |item| -item[:created_at] }.first(LIMIT)
  end

  private

  def communication_items
    TicketCustomerCommunication
      .where(ticket_id: visible_tickets.select(:id))
      # So o que a equipe enviou: a propria resposta do cliente nao e
      # novidade para ele.
      .outbound
      .includes(:user, :ticket)
      .order(created_at: :desc)
      .limit(LIMIT)
      .map { |com| communication_item(com) }
  end

  def communication_item(com)
    {
      type: 'ticket',
      id: "communication_#{com.id}",
      ticket_id: com.ticket_id,
      ticket_display_id: com.ticket.display_id,
      ticket_title: com.ticket.title,
      preview: com.body.to_s.truncate(160),
      author_name: com.user&.name,
      closing: com.closing,
      created_at: (com.sent_at || com.created_at).to_i
    }
  end

  # So existe conversa de chat depois que o cliente abre a aba pela primeira
  # vez - por isso `find_existing`, e nao o servico que cria.
  def chat_items
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(Current.account)
    return [] if inbox.blank?

    conversation = Current.account.conversations.find_by(inbox_id: inbox.id, contact_id: current_contact.id)
    return [] if conversation.blank?

    conversation.messages.chat.outgoing
                .order(created_at: :desc)
                .limit(LIMIT)
                .map { |message| chat_item(message) }
  end

  def chat_item(message)
    {
      type: 'chat',
      id: "chat_#{message.id}",
      ticket_id: nil,
      ticket_display_id: nil,
      ticket_title: nil,
      preview: message.content.to_s.truncate(160),
      author_name: message.sender.is_a?(User) ? message.sender.name : nil,
      closing: false,
      created_at: message.created_at.to_i
    }
  end
end
