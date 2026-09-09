json.payload do
  json.partial! 'api/v1/models/company_category', formats: [:json], resource: @company_category
end
