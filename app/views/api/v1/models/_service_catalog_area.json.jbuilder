json.id resource.id
json.name resource.name
json.active resource.active
json.position resource.position
json.service_catalog_id resource.service_catalog_id
json.items resource.service_catalog_items do |item|
  json.partial! 'api/v1/models/service_catalog_item', formats: [:json], resource: item
end
