# Carrega a Mesa do jeito que o quadro (`api/v1/accounts/teams/show`) precisa:
# Estagios + os tickets de cada um, com tudo o que `_ticket` le ja' pre-carregado.
#
# Qualquer acao que renderize `teams/show` deve passar por aqui. Sem o
# pre-carregamento o quadro dispara uma consulta por associacao POR TICKET (ate'
# 300 tickets por Estagio): foi assim que o `reorder` dos Estagios chegou a levar
# ~14 s e a estourar com erro 500.
module TeamBoardLoading
  extend ActiveSupport::Concern

  # `_ticket` reads all of these; without the preload the board fires a query per
  # association per ticket. `ticket_conversations` and `ticket_checklist_items`
  # matter most: a column with a few hundred cards turned into a few hundred
  # extra queries just for those two (the partial used `.pluck`/`.ordered`,
  # which hit the database even when the association is preloaded - fixed
  # alongside this in `_ticket.json.jbuilder`).
  BOARD_TICKET_INCLUDES = [:team, :ticket_column, :ticket_category, :ticket_complexity, :company, :contact,
                           :project, :blocked_by, :ticket_conversations, :ticket_checklist_items, :sprint,
                           *AssigneeLeveled.assignee_associations,
                           { conversations: :contact }].freeze

  private

  def load_team_board(team_id)
    team = Current.account.teams.includes(:ticket_columns).find(team_id)
    # Carrega `board_tickets` de cada Estagio numa query so' que respeita o
    # limite POR COLUNA (ver TicketColumn.preload_board_tickets!) - encadear
    # `board_tickets` dentro do `includes(ticket_columns: {...})` acima faria o
    # Rails misturar as colunas numa unica query e aplicar o LIMIT na Mesa toda.
    TicketColumn.preload_board_tickets!(team.ticket_columns, includes: BOARD_TICKET_INCLUDES)
    team
  end
end
