json.array! @ticket_timers do |timer|
  json.partial! 'api/v1/models/ticket_timer', formats: [:json], resource: timer
end
