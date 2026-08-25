json.id resource.id
json.ticket_id resource.ticket_id
json.filename resource.file.filename.to_s
json.content_type resource.file.content_type
json.byte_size resource.file.byte_size
json.file_url resource.file_url
json.created_at resource.created_at.to_i
if resource.user
  json.user do
    json.id resource.user.id
    json.name resource.user.name
    json.thumbnail resource.user.avatar_url
  end
else
  json.user nil
end
