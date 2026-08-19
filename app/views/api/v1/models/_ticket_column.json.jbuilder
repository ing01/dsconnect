json.id resource.id
json.name resource.name
json.position resource.position
json.ticket_board_id resource.ticket_board_id
json.tickets resource.tickets do |ticket|
  json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
end
