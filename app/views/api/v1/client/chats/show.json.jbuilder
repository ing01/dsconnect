# O que a tela do Portal precisa para abrir o chat: o token para assinar o
# `RoomChannel` (o MESMO mecanismo do Widget) e o historico ja carregado - sem
# isso a primeira mensagem so apareceria depois do proximo evento em tempo real.
json.pubsub_token @conversation.contact_inbox.pubsub_token
json.conversation_id @conversation.display_id
json.messages @conversation.messages.chat.includes(:attachments).order(created_at: :asc) do |mensagem|
  json.partial! 'api/v1/client/chats/message', resource: mensagem
end
