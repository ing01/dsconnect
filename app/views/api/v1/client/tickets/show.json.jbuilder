json.partial! 'api/v1/client/models/ticket', resource: @ticket

# As tres abas que o cliente enxerga, carregadas junto com o ticket: sao poucas
# linhas e uma ida ao servidor so.

# COMUNICACAO. A conversa do ticket nos dois sentidos: o que a equipe enviou ao
# cliente e o que ele respondeu pela Area do Cliente.
#
# Os comentarios internos (`ticket_comments`) nao aparecem aqui em hipotese
# alguma: sao a conversa da equipe SOBRE o atendimento, nao COM o cliente.
json.communications @ticket.ticket_customer_communications.order(created_at: :desc) do |com|
  json.partial! 'api/v1/client/models/communication', resource: com
end

# VALORIZACAO. As propostas que a equipe liberou ao cliente; as demais nao saem
# do servidor. O cliente le e decide - a decisao tem rota propria.
json.proposals @ticket.ticket_proposals.visible_to_client.ordered do |proposal|
  json.partial! 'api/v1/client/models/proposal', resource: proposal
end

# COMPROMISSOS. Somente leitura: o cliente ve o que foi agendado no atendimento
# dele, e nao ha nada aqui que ele possa criar ou mexer.
json.appointments @ticket.calendar_events.order(:start_at) do |evento|
  json.id evento.id
  json.title evento.title
  json.description evento.description
  json.start_at evento.start_at.to_i
  json.end_at evento.end_at.to_i
  json.all_day evento.all_day
  json.location evento.location
end

# CHECKLIST. Tambem somente leitura - o `completed` e da equipe.
json.checklist_items @ticket.ticket_checklist_items do |item|
  json.id item.id
  json.title item.title
  json.completed item.completed
  json.required item.required
  json.item_type item.item_type
  json.value item.value
  json.position item.position
end
