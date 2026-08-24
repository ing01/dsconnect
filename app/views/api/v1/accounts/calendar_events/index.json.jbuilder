json.payload do
  json.array! @calendar_events do |calendar_event|
    json.partial! 'api/v1/models/calendar_event', formats: [:json], resource: calendar_event
  end
end
