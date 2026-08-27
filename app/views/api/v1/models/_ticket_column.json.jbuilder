json.id resource.id
json.name resource.name
json.position resource.position
json.team_id resource.team_id
# Prazo do Estagio, em segundos. Nulo quando a coluna nao tem prazo.
json.stage_threshold resource.stage_threshold
# Only the operational tickets: resolved, closed and cancelled ones leave the
# Kanban. They stay in the database and remain reachable through the
# "Busca detalhada", which does not apply this scope.
json.tickets resource.operational_tickets do |ticket|
  json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
end
