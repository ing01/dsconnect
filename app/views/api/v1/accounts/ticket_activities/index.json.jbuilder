json.array! @ticket_activities do |ticket_activity|
  json.partial! 'api/v1/models/ticket_activity', formats: [:json], resource: ticket_activity
end
