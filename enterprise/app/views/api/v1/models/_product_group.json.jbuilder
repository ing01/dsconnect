json.id resource.id
json.name resource.name
json.total_value_mode resource.total_value_mode
json.total_value resource.total_value
json.computed_value resource.computed_value
json.products resource.products.map { |product| { id: product.id, name: product.name, value: product.value } }
