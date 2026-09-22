json.payload do
  json.partial! 'api/v1/models/product', formats: [:json], resource: @product
end
