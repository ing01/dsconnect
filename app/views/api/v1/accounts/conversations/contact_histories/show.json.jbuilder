json.meta do
  json.has_more @has_more
end

# Uma linha por conversa anterior que aparece nesta pagina (`display_id` e' o
# mesmo `conversation_id` que vem em cada mensagem).
json.conversations do
  json.array! @history_conversations do |conversation|
    json.display_id conversation.display_id
    json.status conversation.status
    json.created_at conversation.created_at.to_i
    json.inbox_id conversation.inbox_id
    json.inbox_name conversation.inbox&.name
    json.channel_type conversation.inbox&.channel_type
  end
end

json.payload do
  json.array! @messages do |message|
    json.partial! 'api/v1/models/message', message: message
  end
end
