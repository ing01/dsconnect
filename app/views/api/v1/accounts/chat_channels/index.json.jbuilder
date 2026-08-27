json.payload do
  json.array! @chat_channels, partial: 'api/v1/models/chat_channel', as: :resource
end
