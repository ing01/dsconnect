json.payload do
  json.partial! 'api/v1/models/product_group', formats: [:json], resource: @product_group
end
