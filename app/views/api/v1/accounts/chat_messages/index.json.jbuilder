json.payload do
  json.array! @chat_messages, partial: 'api/v1/models/chat_message', as: :resource
end
