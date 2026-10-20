# Conversa ainda nao existe (cliente nunca mandou mensagem): devolve estado
# vazio. O frontend exibe o chat em branco e cria a conversa so no primeiro
# envio (`ChatMessagesController`), evitando que ela apareca no painel do
# atendente sem nenhuma mensagem.
if @conversation.nil?
  json.pubsub_token nil
  json.conversation_id nil
  json.messages []
else
  json.pubsub_token @conversation.contact_inbox&.pubsub_token
  json.conversation_id @conversation.display_id
  json.messages @conversation.messages.chat.includes(:attachments).order(created_at: :asc) do |mensagem|
    json.partial! 'api/v1/client/chats/message', resource: mensagem
  end
end
