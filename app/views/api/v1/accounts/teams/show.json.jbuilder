json.partial! 'api/v1/models/team', formats: [:json], resource: @team
json.ticket_columns @team.ticket_columns do |ticket_column|
  json.partial! 'api/v1/models/ticket_column', formats: [:json], resource: ticket_column
end
