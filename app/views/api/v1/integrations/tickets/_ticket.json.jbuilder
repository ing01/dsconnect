# O payload pensado para a IA de triagem externa analisar e decidir o
# roteamento. De proposito NAO inclui: ticket_comments (thread interna da
# equipe, nunca sai da conta), ticket_activities (auditoria interna),
# ticket_sla_extensions/ticket_applied_slas (nao ajudam a decidir Mesa/Estagio).
json.id resource.id
json.display_id resource.display_id
json.title resource.title
json.description resource.description
json.status resource.status
json.priority resource.priority
json.created_at resource.created_at.iso8601
json.due_date resource.due_date&.iso8601

json.team do
  json.id resource.team_id
  json.name resource.team.name
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
  json.filename attachment.file.filename.to_s
  json.content_type attachment.file.content_type
  json.url attachment.file_url
end
