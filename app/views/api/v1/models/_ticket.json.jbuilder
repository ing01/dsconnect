json.id resource.id
json.display_id resource.display_id
json.title resource.title
json.description resource.description
json.priority resource.priority
json.status resource.status
json.position resource.position
json.account_id resource.account_id
json.ticket_column_id resource.ticket_column_id
json.ticket_column_name resource.ticket_column.name
json.assignee_id resource.assignee_id
json.assignee_name resource.assignee&.name
# Os responsaveis do Nivel 2 em diante, so os niveis que a Mesa deste ticket usa.
# Emitir todos os cinco sempre engordaria o payload do Kanban, que inlina cada
# ticket de cada Estagio, com campos que aquela Mesa nao tem como preencher.
(AssigneeLeveled::MIN_LEVEL..resource.team.assignee_levels_count).each do |level|
  json.set! AssigneeLeveled.assignee_column(level), resource[AssigneeLeveled.assignee_column(level)]
  json.set! :"assignee_#{level}_name", resource.assignee_for_level(level)&.name
end
json.team_id resource.team_id
json.team_name resource.team.name
# Solicitante still comes from a linked Conversation's Contact - there is no
# ticket->contact FK. Empresa, in contrast, is now a real association on the
# ticket, so it is read straight from it.
json.requester_name resource.requester_contact&.name
json.contact_id resource.contact_id
json.service_catalog_item_id resource.service_catalog_item_id
json.ticket_category_id resource.ticket_category_id
json.ticket_category_name resource.ticket_category&.name
json.company_id resource.company_id
json.company_name resource.company&.name
json.project_id resource.project_id
json.project_name resource.project&.name
json.project_task_template_id resource.project_task_template_id
json.due_date resource.due_date&.iso8601
json.scheduled_at resource.scheduled_at&.iso8601
json.next_project_stage resource.next_project_stage
json.resolved_at resource.resolved_at&.to_i
json.closed_at resource.closed_at&.to_i
json.cancelled_at resource.cancelled_at&.to_i
# Why the ticket left the open state ('merged', 'cancelled', or nil for a plain
# close). Plain columns, so the board pays nothing extra for them, and the
# Kanban card can badge a grouped or child ticket without a second request.
json.close_reason resource.close_reason

# Impedimento. Vai no partial enxuto - e nao so no detalhe - porque o cartao do
# Kanban precisa marcar visualmente o ticket impedido, e a listagem precisa
# mostra-lo sem uma segunda consulta.
# Triagem: chamado aberto pelo cliente que ainda nao foi aceito pela equipe.
json.pending_triage resource.pending_triage
json.triaged_at resource.triaged_at&.to_i
json.blocked resource.blocked?
json.blocked_at resource.blocked_at&.to_i
json.blocked_reason resource.blocked_reason
json.blocked_by do
  if resource.blocked_by.present?
    json.id resource.blocked_by.id
    json.name resource.blocked_by.name
  else
    json.nil!
  end
end
json.parent_id resource.parent_id
json.merged_into_id resource.merged_into_id
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
json.conversation_ids resource.ticket_conversations.pluck(:conversation_id)
json.checklist_items resource.ticket_checklist_items.ordered do |item|
  json.id item.id
  json.title item.title
  json.completed item.completed
  json.completed_at item.completed_at&.iso8601
  json.completed_by_id item.completed_by_id
  json.position item.position
end
