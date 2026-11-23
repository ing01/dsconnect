# O parentesco do ticket, para quem le pela API saber se ele tem filho (ou e' filho de alguem):
#   - parent_ticket_id: o id do pai, ou nulo;
#   - child_tickets: os filhos (todos os status), ordenados por id; lista vazia quando nao tem.
json.parent_ticket_id ticket.parent_id
json.child_tickets ticket.children.sort_by(&:id) do |child|
  json.id child.id
  json.display_id child.display_id
  json.team_id child.team_id
  json.ticket_column_id child.ticket_column_id
  json.status child.status
end
