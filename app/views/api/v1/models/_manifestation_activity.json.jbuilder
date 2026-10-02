# Uma linha do historico. Sempre com autor e hora - e para isso que ela existe.
json.id resource.id
json.activity_type resource.activity_type
json.previous_value resource.previous_value
json.new_value resource.new_value
json.meta resource.meta
json.created_at resource.created_at.to_i
json.author_name resource.author_name
json.from_client resource.contact_id.present?
