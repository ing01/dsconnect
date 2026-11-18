json.array! @teams do |team|
  json.id team.id
  json.name team.name
  json.ticket_columns team.ticket_columns do |column|
    json.id column.id
    json.name column.name
    # O que o Estagio exige de um ticket que entra nele - quem move pela API precisa mandar
    # junto (assignee_id, due_date, scheduled_at) ou o movimento e' recusado (422).
    json.requires do
      json.assignee column.require_assignee
      json.due_date column.require_due_date
      json.scheduled_at column.require_scheduled_at
      json.appointment column.require_appointment
    end
  end
end
