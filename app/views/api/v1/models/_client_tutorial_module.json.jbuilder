json.id resource.id
json.name resource.name
json.description resource.description
json.logo_url resource.logo_url
json.logo_name resource.logo.attached? ? resource.logo.filename.to_s : nil
json.position resource.position
json.active resource.active
