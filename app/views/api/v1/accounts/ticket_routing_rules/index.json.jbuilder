json.payload @ticket_routing_rules do |rule|
  json.id rule.id
  json.client_level rule.client_level
  json.team_id rule.team_id
  json.team_name rule.team.name
end
