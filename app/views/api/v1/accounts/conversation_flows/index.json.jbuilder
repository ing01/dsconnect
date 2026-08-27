json.array! @conversation_flows do |conversation_flow|
  json.partial! 'api/v1/models/conversation_flow', formats: [:json], resource: conversation_flow
end
