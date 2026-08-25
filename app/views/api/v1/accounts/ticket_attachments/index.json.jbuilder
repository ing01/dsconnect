json.array! @ticket_attachments do |attachment|
  json.partial! 'api/v1/models/ticket_attachment', formats: [:json], resource: attachment
end
