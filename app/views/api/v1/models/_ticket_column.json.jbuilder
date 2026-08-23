json.id resource.id
json.name resource.name
json.position resource.position
json.team_id resource.team_id
json.tickets resource.tickets do |ticket|
  json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
end
