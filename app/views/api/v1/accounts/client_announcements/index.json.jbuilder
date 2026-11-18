json.array! @announcements do |announcement|
  json.partial! 'api/v1/models/client_announcement', formats: [:json], resource: announcement
end
