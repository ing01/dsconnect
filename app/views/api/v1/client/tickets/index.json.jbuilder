# O Kanban do cliente, no MESMO formato do quadro interno.
#
# A tela do cliente monta os componentes reais do Kanban (TicketBoard ->
# TicketBoardColumn -> TicketCard), e eles leem `ticket_columns[].tickets[]`.
# Devolver outra forma obrigaria a uma segunda tela, que e justamente o que nao
# se quer.
#
# O `_team` do painel NAO e reaproveitado aqui: ele emite
# `Current.user.teams.include?`, e nao ha usuario interno nesta sessao.
json.id @team&.id
json.name @team&.name

# As Mesas em que o cliente tem chamado - alimentam o seletor de Mesa.
json.teams @teams do |team|
  json.id team.id
  json.name team.name
end

json.ticket_columns @columns do |column|
  json.id column.id
  json.name column.name
  json.position column.position
  json.team_id column.team_id
  json.kind column.kind
  json.stage_threshold column.stage_threshold

  # A diferenca para o `_ticket_column` do painel esta aqui: ele emite
  # `column.operational_tickets`, que sao TODOS os da coluna. O cliente recebe
  # apenas os que ja passaram por `visible_tickets` - a fronteira continua no
  # servidor, e nao no componente.
  json.tickets(@tickets_by_column[column.id] || []) do |ticket|
    json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
  end
end
