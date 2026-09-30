# A mesma forma de mensagem do chat "de agora" (`api/v1/client/chats/_message`)
# - so leitura, sem `pubsub_token`: uma sessao encerrada nao recebe mensagem
# nova, entao nao ha o que assinar.
json.id @conversation.display_id
json.created_at @conversation.created_at.to_i
json.resolved_at (@conversation.status_changed_at || @conversation.updated_at).to_i
json.messages @conversation.messages.chat.includes(:attachments).order(created_at: :asc) do |mensagem|
  json.partial! 'api/v1/client/chats/message', resource: mensagem
end
