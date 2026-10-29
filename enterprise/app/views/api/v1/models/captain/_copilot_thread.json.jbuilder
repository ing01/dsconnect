json.id resource.id
json.title resource.title
json.created_at resource.created_at.to_i
json.user resource.user.push_event_data
json.assistant resource.assistant.push_event_data
json.account_id resource.account_id
json.conversation_display_id resource.conversation_display_id
json.conversation do
  conversation = resource.conversation
  json.display_id conversation&.display_id
  json.contact_name conversation&.contact&.name
end
json.ticket do
  ticket = resource.ticket
  json.id ticket&.id
  json.display_id ticket&.display_id
  json.title ticket&.title
end
# O nome da rota da tela, quando nao foi numa conversa nem num ticket.
json.screen resource.screen
