json.id resource.id
json.name resource.name
json.position resource.position
json.team_id resource.team_id
# Only the operational tickets: resolved, closed and cancelled ones leave the
# Kanban. They stay in the database and remain reachable through the
# "Busca detalhada", which does not apply this scope.
json.tickets resource.operational_tickets do |ticket|
  json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
end
