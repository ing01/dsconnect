json.id resource.id
json.field_id resource.field_id
json.value resource.value
if resource.file.attached?
  json.filename resource.file.filename.to_s
  json.file_url resource.file_url
end
