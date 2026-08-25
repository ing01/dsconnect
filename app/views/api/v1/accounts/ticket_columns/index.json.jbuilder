# Intentionally not the `_ticket_column` partial: that one inlines every ticket
# of the column, which is exactly the payload this endpoint exists to avoid.
json.array! @ticket_columns do |ticket_column|
  json.id ticket_column.id
  json.name ticket_column.name
  json.position ticket_column.position
  json.team_id ticket_column.team_id
end
