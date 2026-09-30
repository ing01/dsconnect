# A ordenacao dos cabecalhos da Busca detalhada.
#
# Fica no servidor, e nao no navegador, porque a lista e paginada la: ordenar
# so a pagina carregada mostraria o menor numero DAQUELAS 25 linhas, e nao o
# menor do resultado inteiro - que e o que quem clica no cabecalho espera ver.
#
# So filtra a ordem; os filtros continuam sendo do TicketFinder.
module Tickets::SearchOrdering
  # Coluna do cabecalho -> por onde ordenar, e o join que ela exige.
  #
  # Lista fechada de proposito: o nome vem da URL e termina dentro de um ORDER
  # BY. Aceitar qualquer texto ali seria injecao de SQL.
  COLUMNS = {
    'display_id' => { column: 'tickets.display_id' },
    'created_at' => { column: 'tickets.created_at' },
    'title' => { column: 'tickets.title' },
    'status' => { column: 'tickets.status' },
    'company' => { column: 'companies.name', join: :company },
    'contact' => { column: 'contacts.name', join: :contact },
    'team' => { column: 'teams.name', join: :team },
    'ticket_column' => { column: 'ticket_columns.name', join: :ticket_column },
    'assignee' => { column: 'users.name', join: :assignee },
    'ticket_complexity' => { column: 'ticket_complexities.name', join: :ticket_complexity }
  }.freeze

  DEFAULT_COLUMN = 'tickets.created_at'.freeze

  class << self
    def apply(relation, sort_by:, sort_order:)
      config = COLUMNS[sort_by.to_s]
      return relation.order(Arel.sql("#{DEFAULT_COLUMN} DESC")) if config.blank?

      relation = relation.left_joins(config[:join]) if config[:join]
      # Desempate por id: sem uma ordem total, duas linhas de mesmo valor podem
      # trocar de lugar entre uma pagina e outra, e uma delas some enquanto a
      # outra aparece duas vezes.
      relation.order(Arel.sql("#{config[:column]} #{direction(sort_order)} NULLS LAST")).order(id: :asc)
    end

    private

    # Normalizado aqui: e o outro valor que vem da URL e entra no SQL.
    def direction(sort_order)
      sort_order.to_s.casecmp('asc').zero? ? 'ASC' : 'DESC'
    end
  end
end
