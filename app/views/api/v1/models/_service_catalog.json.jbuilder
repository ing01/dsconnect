# The whole tree in one payload: it is small, and both the settings screen and
# the classification dialog need all three levels at once.
json.id resource.id
json.name resource.name
json.active resource.active
json.position resource.position
json.areas resource.service_catalog_areas do |area|
  json.partial! 'api/v1/models/service_catalog_area', formats: [:json], resource: area
end
