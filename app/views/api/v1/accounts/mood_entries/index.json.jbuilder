json.payload do
  json.array! @mood_entries do |mood_entry|
    json.partial! 'api/v1/models/mood_entry', formats: [:json], resource: mood_entry
  end
end
