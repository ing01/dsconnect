json.payload do
  json.array! @company_sub_niches do |company_sub_niche|
    json.partial! 'api/v1/models/company_sub_niche', formats: [:json], resource: company_sub_niche
  end
end
