json.array! @sprints do |sprint|
  json.id sprint.id
  json.name sprint.name
  json.team_id sprint.team_id
  json.team_name sprint.team.name
  json.starts_on sprint.starts_on
  json.ends_on sprint.ends_on
  json.status sprint.status
  json.active sprint.active?
end
