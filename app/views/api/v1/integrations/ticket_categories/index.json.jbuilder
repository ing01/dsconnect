json.array! @teams do |team|
  json.team_id team.id
  json.team_name team.name
  json.ticket_categories team.ticket_categories do |category|
    json.id category.id
    json.name category.name
  end
end
