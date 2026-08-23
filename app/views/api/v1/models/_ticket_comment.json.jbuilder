json.id resource.id
json.ticket_id resource.ticket_id
json.content resource.content
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
json.user do
  json.id resource.user.id
  json.name resource.user.name
  json.avatar_url resource.user.avatar_url
end
