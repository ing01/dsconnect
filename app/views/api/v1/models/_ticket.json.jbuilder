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
json.team_id resource.team_id
json.team_name resource.team.name
# Solicitante still comes from a linked Conversation's Contact - there is no
# ticket->contact FK. Empresa, in contrast, is now a real association on the
# ticket, so it is read straight from it.
json.requester_name resource.requester_contact&.name
json.company_id resource.company_id
json.company_name resource.company&.name
json.resolved_at resource.resolved_at&.to_i
json.closed_at resource.closed_at&.to_i
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
json.conversation_ids resource.ticket_conversations.pluck(:conversation_id)
