json.array! @teams do |team|
  json.id team.id
  json.name team.name
  json.ticket_columns team.ticket_columns do |column|
    json.id column.id
    json.name column.name
  end
end
