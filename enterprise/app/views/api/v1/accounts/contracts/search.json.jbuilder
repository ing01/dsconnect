json.meta do
  json.total_count @contracts_count
  json.page @current_page
end

json.payload do
  json.array! @contracts do |contract|
    json.partial! 'api/v1/models/contract', formats: [:json], resource: contract
  end
end
