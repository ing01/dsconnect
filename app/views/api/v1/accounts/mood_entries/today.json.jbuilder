json.payload do
  json.partial! 'api/v1/models/mood_entry', formats: [:json], resource: @mood_entry if @mood_entry
end
