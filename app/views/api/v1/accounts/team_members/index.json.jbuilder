json.array! @team_members do |team_member|
  json.partial! 'api/v1/models/agent', formats: [:json], resource: team_member
  json.levels @levels_by_user[team_member.id] || []
end
