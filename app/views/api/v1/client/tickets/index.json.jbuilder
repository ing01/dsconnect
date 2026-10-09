# A lista de chamados do cliente, com as Mesas todas juntas - cada chamado ja
# traz consigo onde esta (`team_name`/`ticket_column_name`, no partial), e nao
# ha mais um recorte por Mesa pra escolher antes de ver os proprios tickets.
#
# O partial usado e o do painel interno (`api/v1/models/ticket`), e nao o
# `api/v1/client/models/ticket`: a fronteira do cliente e de LINHAS (ver
# `visible_tickets`), nao de campos - o cartao precisa dos mesmos dados que o
# Kanban interno le (responsavel incluso).
json.companies @companies do |company|
  json.id company.id
  json.name company.name
end

json.tickets @tickets do |ticket|
  json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
end
