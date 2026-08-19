json.id resource.id
json.name resource.name
json.account_id resource.account_id
json.ticket_columns resource.ticket_columns do |ticket_column|
  json.partial! 'api/v1/models/ticket_column', formats: [:json], resource: ticket_column
end
