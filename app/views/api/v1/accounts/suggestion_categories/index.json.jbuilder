json.array! @suggestion_categories do |suggestion_category|
  json.partial! 'api/v1/models/suggestion_category', formats: [:json], resource: suggestion_category
end
