json.array! @ticket_boards do |ticket_board|
  json.partial! 'api/v1/models/ticket_board', formats: [:json], resource: ticket_board
end
