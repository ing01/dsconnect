json.payload do
  json.array! @company_niches do |company_niche|
    json.partial! 'api/v1/models/company_niche', formats: [:json], resource: company_niche
  end
end
