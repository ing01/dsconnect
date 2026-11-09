# O payload pensado para a IA de triagem externa analisar e decidir o
# roteamento (e, agora, pra um sistema de desenvolvimento ler/gravar os
# proprios campos via `custom_attributes`). De proposito NAO inclui:
# ticket_comments (thread interna da equipe - ver TicketCommentsController
# para leitura dedicada), ticket_activities (auditoria interna),
# ticket_sla_extensions/ticket_applied_slas (nao ajudam a decidir Mesa/Estagio).
json.id resource.id
json.display_id resource.display_id
json.title resource.title
json.description resource.description
json.status resource.status
json.priority resource.priority
# Campos do desenvolvimento: `story` (Historia) alem de bug/task; `sprint_id` nil = Backlog.
json.development_type resource.development_type
json.sprint_id resource.sprint_id
json.created_at resource.created_at.iso8601
json.updated_at resource.updated_at.iso8601
json.due_date resource.due_date&.iso8601
# Qualquer chave: a IA de triagem e sistemas de desenvolvimento usam isto
# como um "campo livre" (analise, observacoes do dev, documentacao, horas...)
# - ver `apply_custom_attributes` no controller, que faz MERGE em vez de
# substituir o jsonb inteiro.
json.custom_attributes resource.custom_attributes
# Os campos do card do Jira tambem como primeiro nivel (mesmo valor que esta em
# `custom_attributes`) - `nil` quando ainda nao preenchidos.
Ticket::LONG_TEXT_CUSTOM_ATTRIBUTES.each do |field|
  json.set! field, resource.custom_attributes[field]
end

json.team do
  json.id resource.team_id
  json.name resource.team.name
end

if resource.assignee
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.name
    json.email resource.assignee.email
  end
else
  json.assignee nil
end

json.ticket_column do
  json.id resource.ticket_column_id
  json.name resource.ticket_column.name
end

if resource.ticket_category
  json.ticket_category do
    json.id resource.ticket_category.id
    json.name resource.ticket_category.name
  end
else
  json.ticket_category nil
end

if resource.ticket_complexity
  json.ticket_complexity do
    json.id resource.ticket_complexity.id
    json.name resource.ticket_complexity.name
  end
else
  json.ticket_complexity nil
end

if resource.company
  json.company do
    json.id resource.company.id
    json.name resource.company.name
  end
else
  json.company nil
end

requester = resource.requester_contact
if requester
  json.requester do
    json.name requester.name
    json.email requester.email
  end
else
  json.requester nil
end

json.customer_communications resource.ticket_customer_communications.sort_by(&:created_at) do |communication|
  json.direction communication.direction
  json.body communication.body
  json.sent_at (communication.sent_at || communication.created_at).iso8601
  json.author_name communication.author_name
end

json.attachments resource.ticket_attachments do |attachment|
  json.id attachment.id
  json.filename attachment.file.filename.to_s
  json.content_type attachment.file.content_type
  json.url attachment.file_url
end
