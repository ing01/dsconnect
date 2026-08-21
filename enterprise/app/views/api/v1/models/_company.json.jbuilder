json.id resource.id
json.name resource.name
json.contacts_count resource.contacts_count
json.domain resource.domain
json.description resource.description
json.custom_attributes resource.custom_attributes
json.avatar_url resource.avatar_url
json.legal_name resource.legal_name
json.cnpj resource.cnpj
json.ie resource.ie
json.im resource.im
json.address_zip_code resource.address_zip_code
json.address_street resource.address_street
json.address_number resource.address_number
json.address_complement resource.address_complement
json.address_neighborhood resource.address_neighborhood
json.address_city resource.address_city
json.address_state resource.address_state
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
json.updated_at resource.updated_at.to_i if resource[:updated_at].present?
