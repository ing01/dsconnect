json.id resource.id
json.title resource.title
json.created_at resource.created_at.to_i
json.user resource.user.push_event_data
json.assistant resource.assistant.push_event_data
json.account_id resource.account_id
json.conversation_display_id resource.conversation_display_id
json.ticket do
  ticket = resource.ticket
  json.id ticket&.id
  json.display_id ticket&.display_id
end
