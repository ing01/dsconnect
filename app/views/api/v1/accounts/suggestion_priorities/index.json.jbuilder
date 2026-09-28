json.array! @suggestion_priorities do |suggestion_priority|
  json.partial! 'api/v1/models/suggestion_priority', formats: [:json], resource: suggestion_priority
end
