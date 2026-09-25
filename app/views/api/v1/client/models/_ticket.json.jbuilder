# O ticket como o CLIENTE o ve.
#
# Partial proprio, e nao o `api/v1/models/_ticket`: aquele carrega responsavel,
# SLA, impedimento, seguidores e a Empresa - informacao interna do atendimento.
# Filtrar no frontend nao serviria: o dado ja teria saido daqui.
json.id resource.id
json.display_id resource.display_id
json.title resource.title
json.description resource.description
json.status resource.status
# Aguardando triagem: o chamado chegou, mas a equipe ainda nao o aceitou. O
# Estagio em que ele aparece e provisorio ate la, e dizer isso e mais honesto
# do que mostrar uma coluna que vai mudar.
json.pending_triage resource.pending_triage
json.priority resource.priority
json.position resource.position
json.ticket_column_id resource.ticket_column_id
json.ticket_column_name resource.ticket_column.name
json.team_id resource.team_id
json.team_name resource.team.name
json.category_name resource.ticket_category&.name
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
json.closed_at resource.closed_at&.to_i
# Quem abriu, do lado do cliente: serve para o contato distinguir o que e dele
# do que e de um colega, quando ele enxerga os chamados da empresa toda.
json.requested_by resource.contact&.name
json.requested_by_me resource.contact_id == Current.contact&.id
json.due_date resource.due_date&.to_i
json.scheduled_at resource.scheduled_at&.to_i
