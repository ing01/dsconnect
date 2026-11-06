# Historico do cliente dentro da conversa: as mensagens das conversas ANTERIORES
# da mesma pessoa, de qualquer canal, para o agente ver o que ja foi falado quando
# ela abre uma conversa nova. Cliente realmente novo nao tem conversa anterior, e
# a resposta vem vazia.
#
# So' entram conversas que o usuario pode ver (mesma regra da lista de conversas
# do contato). A pagina vai da mais nova para a mais antiga e e' devolvida em
# ordem cronologica; `before` e' o id da mensagem mais antiga ja carregada.
# A ordem e' (conversa, mensagem): cada conversa anterior forma um bloco, mesmo
# que duas tenham acontecido ao mesmo tempo em canais diferentes.
class Api::V1::Accounts::Conversations::ContactHistoriesController < Api::V1::Accounts::Conversations::BaseController
  PAGE_SIZE = 40

  def show
    rows = page_scope.limit(PAGE_SIZE + 1).to_a
    @has_more = rows.size > PAGE_SIZE
    @messages = rows.first(PAGE_SIZE).reverse
    @history_conversations = previous_conversations.where(id: @messages.map(&:conversation_id).uniq).includes(:inbox)
  end

  private

  def previous_conversations
    @previous_conversations ||= build_previous_conversations
  end

  def build_previous_conversations
    return Conversation.none if @conversation.contact_id.blank?

    scope = Current.account.conversations
                   .where(contact_id: @conversation.contact_id)
                   .where('conversations.id < ?', @conversation.id)
    Conversations::PermissionFilterService.new(scope, Current.user, Current.account).perform
  end

  def permitted_messages
    Message.where(conversation_id: previous_conversations.select(:id))
  end

  def page_scope
    apply_cursor(permitted_messages)
      .reorder(conversation_id: :desc, id: :desc)
      .includes(:conversation, :attachments, :sender, sender: { avatar_attachment: [:blob] })
  end

  # Mensagens antes da ja carregada, na ordem (conversa, mensagem). A ancora tem
  # que estar no historico permitido - qualquer outro id nao devolve nada.
  def apply_cursor(scope)
    return scope if params[:before].blank?

    anchor = scope.find_by(id: params[:before].to_i)
    return scope.none if anchor.blank?

    scope.where(
      'messages.conversation_id < :conversation_id OR (messages.conversation_id = :conversation_id AND messages.id < :id)',
      conversation_id: anchor.conversation_id, id: anchor.id
    )
  end
end
