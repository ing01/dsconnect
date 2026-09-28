json.array! @suggestion_columns do |suggestion_column|
  json.partial! 'api/v1/models/suggestion_column', formats: [:json], resource: suggestion_column
end
