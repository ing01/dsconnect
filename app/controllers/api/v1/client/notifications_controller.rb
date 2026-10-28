# As novidades do cliente: o que a equipe escreveu nos chamados dele
# (`ticket_customer_communications`) e o que a equipe respondeu no chat do
# Portal - juntos, do mais recente para o mais antigo.
#
# Continua sem tabela de notificacao propria: as DUAS fontes ja existem, e o
# que muda aqui e' so juntar as duas listas antes de cortar pelo limite.
# O estado de lido/removido mora em ClientNotificationDismissal, guardado so'
# pela CHAVE sintetica do item (ver `communication_item`/`chat_item`) - nao
# ha' onde gravar um "lido" dentro da propria TicketCustomerCommunication ou
# Message sem misturar o que e' do agente com o que e' do contato.
class Api::V1::Client::NotificationsController < Api::V1::Client::BaseController
  LIMIT = 50

  def index
    @items = visible_items
  end

  # Abrir (ou um botao de remover) dispensa UM item - ele so' some da lista,
  # nunca apaga a comunicacao/mensagem original.
  def dismiss
    upsert_dismissals([params[:id]])
    head :ok
  end

  # "Limpar tudo": dispensa so' o que a tela estaria mostrando agora, nao
  # qualquer comunicacao que algum dia tenha existido.
  def dismiss_all
    upsert_dismissals(visible_items.pluck(:id))
    head :ok
  end

  private

  def visible_items
    @visible_items ||= all_items.reject { |item| dismissed_keys.include?(item[:id]) }.first(LIMIT)
  end

  def all_items
    @all_items ||= (communication_items + chat_items).sort_by { |item| -item[:created_at] }
  end

  def dismissed_keys
    @dismissed_keys ||= current_contact.client_notification_dismissals
                                       .where(account_id: Current.account.id)
                                       .pluck(:item_key).to_set
  end

  # `upsert_all` pula validacao/callback de proposito: isto e' so' um upsert
  # idempotente de chave (conta+contato+item_key), nao um registro com regra
  # de negocio - e evita estourar em corrida (duplo clique) sem precisar de
  # `rescue` pra unicidade.
  # rubocop:disable Rails/SkipsModelValidations
  def upsert_dismissals(keys)
    return if keys.blank?

    agora = Time.current
    registros = keys.map do |key|
      { account_id: Current.account.id, contact_id: current_contact.id,
        item_key: key, dismissed_at: agora, created_at: agora, updated_at: agora }
    end
    ClientNotificationDismissal.upsert_all(registros, unique_by: :idx_client_notif_dismissals_on_contact_and_key)
  end
  # rubocop:enable Rails/SkipsModelValidations

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
  #
  # TODAS as conversas do contato nessa caixa, e nao uma so': o chat abre uma
  # conversa NOVA a cada sessao resolvida (`Client::ChatConversationResolver`),
  # entao o contato acumula varias. Ler apenas "a" conversa pegava uma qualquer
  # (a mais antiga, na pratica) e a resposta da equipe na sessao atual nunca
  # aparecia aqui - sem item na lista, a bolinha do Chat nao acendia.
  def chat_items
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(Current.account)
    return [] if inbox.blank?

    conversation_ids = Current.account.conversations
                              .where(inbox_id: inbox.id, contact_id: current_contact.id).select(:id)

    Message.chat.outgoing
           .where(account_id: Current.account.id, conversation_id: conversation_ids)
           .includes(:attachments, :sender)
           .order(created_at: :desc)
           .limit(LIMIT)
           .map { |message| chat_item(message) }
  end

  # Mensagem so com arquivo (foto, audio) nao tem texto: sem isto a notificacao
  # apareceria em branco e o cliente nao entenderia o que chegou.
  def chat_preview(message)
    return message.content.to_s.truncate(160) if message.content.present?

    message.attachments.any? ? I18n.t('client_area.chat.push_attachment_body') : ''
  end

  def chat_item(message)
    {
      type: 'chat',
      id: "chat_#{message.id}",
      ticket_id: nil,
      ticket_display_id: nil,
      ticket_title: nil,
      preview: chat_preview(message),
      author_name: message.sender.is_a?(User) ? message.sender.name : nil,
      closing: false,
      conversation_id: message.conversation_id,
      created_at: message.created_at.to_i
    }
  end
end
