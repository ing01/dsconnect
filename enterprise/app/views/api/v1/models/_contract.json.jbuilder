json.id resource.id
json.contract_type resource.contract_type
json.total_value_mode resource.total_value_mode
json.total_value resource.total_value
json.computed_total_value resource.computed_total_value
json.responsible_contact_id resource.responsible_contact_id
json.responsible_contact (resource.responsible_contact ? { id: resource.responsible_contact.id, name: resource.responsible_contact.name } : nil)
json.companies resource.companies.map { |company| { id: company.id, name: company.name } }
json.contract_products resource.contract_products.map { |line|
  {
    id: line.id,
    product_id: line.product_id,
    product_name: line.product.name,
    unit_value: line.unit_value,
    licenses_qty: line.licenses_qty,
    implementation_fee: line.implementation_fee
  }
}
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
