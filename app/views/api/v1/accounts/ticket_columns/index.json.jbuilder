# Intentionally not the `_ticket_column` partial: that one inlines every ticket
# of the column, which is exactly the payload this endpoint exists to avoid.
json.array! @ticket_columns do |ticket_column|
  json.id ticket_column.id
  json.name ticket_column.name
  json.position ticket_column.position
  json.team_id ticket_column.team_id
  json.stage_threshold ticket_column.stage_threshold
  json.require_due_date ticket_column.require_due_date
  json.require_scheduled_at ticket_column.require_scheduled_at
  json.require_appointment ticket_column.require_appointment
  json.require_assignee ticket_column.require_assignee
end
