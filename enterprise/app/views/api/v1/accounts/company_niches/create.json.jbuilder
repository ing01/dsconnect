json.payload do
  json.partial! 'api/v1/models/company_niche', formats: [:json], resource: @company_niche
end
