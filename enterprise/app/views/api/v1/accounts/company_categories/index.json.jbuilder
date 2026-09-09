json.payload do
  json.array! @company_categories do |company_category|
    json.partial! 'api/v1/models/company_category', formats: [:json], resource: company_category
  end
end
