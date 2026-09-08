json.array! @ticket_time_entries do |entry|
  json.partial! 'api/v1/models/ticket_time_entry', formats: [:json], resource: entry
end
