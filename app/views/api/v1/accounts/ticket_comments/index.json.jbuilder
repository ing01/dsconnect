json.array! @ticket_comments do |ticket_comment|
  json.partial! 'api/v1/models/ticket_comment', formats: [:json], resource: ticket_comment
end
