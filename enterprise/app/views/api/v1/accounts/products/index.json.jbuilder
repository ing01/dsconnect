json.payload do
  json.array! @products do |product|
    json.partial! 'api/v1/models/product', formats: [:json], resource: product
  end
end
