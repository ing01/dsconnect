json.array! @service_catalogs do |catalog|
  json.partial! 'api/v1/models/service_catalog', formats: [:json], resource: catalog
end
