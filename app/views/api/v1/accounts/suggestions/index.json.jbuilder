json.array! @suggestions do |suggestion|
  json.partial! 'api/v1/models/suggestion', formats: [:json], resource: suggestion
end
