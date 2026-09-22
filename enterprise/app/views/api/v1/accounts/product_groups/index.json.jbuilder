json.payload do
  json.array! @product_groups do |product_group|
    json.partial! 'api/v1/models/product_group', formats: [:json], resource: product_group
  end
end
