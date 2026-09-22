json.payload do
  json.partial! 'api/v1/models/contract', formats: [:json], resource: @contract
end
