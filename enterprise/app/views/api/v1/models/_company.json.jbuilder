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
json.billing_type resource.billing_type
json.billing_amount resource.billing_amount
json.implementation_fee resource.implementation_fee
json.system_started_on resource.system_started_on
json.projects_count resource.projects.count
json.contract_id resource.contract_id
if resource.contract.present?
  json.contract do
    json.id resource.contract.id
    json.description resource.contract.description
    json.display_label resource.contract.display_label
    json.contract_type resource.contract.contract_type
    json.computed_total_value resource.contract.computed_total_value
    json.company_names resource.contract.companies.pluck(:name)
  end
else
  json.contract nil
end
json.system_modules resource.system_modules.map { |system_module| { id: system_module.id, name: system_module.name } }
json.client_level resource.client_level
json.campaign_opt_in resource.campaign_opt_in
json.blocked resource.blocked
json.company_category_id resource.company_category_id
json.company_category (resource.company_category ? { id: resource.company_category.id, name: resource.company_category.name } : nil)
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
json.updated_at resource.updated_at.to_i if resource[:updated_at].present?
