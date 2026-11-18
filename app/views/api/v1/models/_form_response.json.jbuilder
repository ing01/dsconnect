json.id resource.id
json.form_id resource.form_id
json.ticket_id resource.ticket_id
json.ticket_display_id resource.ticket.display_id
json.filled_by_name resource.filled_by&.name
json.created_at resource.created_at.to_i
json.answers resource.form_answers do |answer|
  json.partial! 'api/v1/models/form_answer', formats: [:json], resource: answer
end
