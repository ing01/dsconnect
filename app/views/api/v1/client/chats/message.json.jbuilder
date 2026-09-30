# `conversation_id`/`pubsub_token` junto da mensagem: e' como a tela do
# cliente percebe que a sessao mudou (conversa anterior foi resolvida) e se
# resubscreve sozinha, sem precisar de um segundo `GET /chat`.
json.partial! 'api/v1/client/chats/message', resource: @message
json.conversation_id @message.conversation.display_id
json.pubsub_token @message.conversation.contact_inbox.pubsub_token
