# Relatorio de tickets: uma linha por ticket, com os dados de triagem que o
# board ja tem (numero, cliente, catalogo, mesa, responsavel, categoria,
# status) - sem agregar nada, e' a lista em si, pronta para ser filtrada e
# conferida cliente a cliente.
#
# Todos os filtros sao opcionais e se acumulam.
class Tickets::TicketReportBuilder
  pattr_initialize [:account!, :params!]

  def perform
    scope
      .includes(:company, :team, :assignee, :ticket_category,
                service_catalog_item: { service_catalog_area: :service_catalog })
      .order(display_id: :desc)
      .map { |ticket| row_for(ticket) }
  end

  private

  def scope
    filter_by_dates(filter_by_service_catalog(filter_by_attributes(account.tickets)))
  end

  def filter_by_attributes(relation)
    { company_id: params[:company_id], status: params[:status], assignee_id: params[:assignee_id] }
      .compact_blank
      .reduce(relation) { |result, (column, value)| result.where(column => value) }
  end

  # O filtro e' pelo Catalogo (nivel 1) - o ticket so' guarda o Item (nivel 3),
  # entao precisa subir dois niveis pela Area para chegar nele.
  def filter_by_service_catalog(relation)
    return relation if params[:service_catalog_id].blank?

    relation.joins(service_catalog_item: :service_catalog_area)
            .where(service_catalog_areas: { service_catalog_id: params[:service_catalog_id] })
  end

  # "Fechamento" nao e' uma coluna so': um ticket sai do estado aberto por
  # resolucao, encerramento ou cancelamento, e o filtro de data cobre as tres
  # do mesmo jeito que a coluna exibida (`row_for`) ja faz.
  def filter_by_dates(relation)
    relation = relation.where(created_at: opened_from..) if opened_from
    relation = relation.where(created_at: ..opened_to.end_of_day) if opened_to
    relation = relation.where('COALESCE(closed_at, resolved_at, cancelled_at) >= ?', closed_from) if closed_from
    relation = relation.where('COALESCE(closed_at, resolved_at, cancelled_at) <= ?', closed_to.end_of_day) if closed_to
    relation
  end

  def row_for(ticket)
    {
      id: ticket.id,
      display_id: ticket.display_id,
      title: ticket.title,
      company_id: ticket.company_id,
      company_name: ticket.company&.name,
      service_catalog_id: ticket.service_catalog_item&.service_catalog_area&.service_catalog_id,
      service_catalog_name: ticket.service_catalog_item&.service_catalog&.name,
      team_id: ticket.team_id,
      team_name: ticket.team&.name,
      assignee_id: ticket.assignee_id,
      assignee_name: ticket.assignee&.name,
      ticket_category_id: ticket.ticket_category_id,
      category_name: ticket.ticket_category&.name,
      status: ticket.status,
      created_at: ticket.created_at,
      closed_at: ticket.closed_at || ticket.resolved_at || ticket.cancelled_at
    }
  end

  def opened_from
    @opened_from ||= parse_date(params[:opened_from])
  end

  def opened_to
    @opened_to ||= parse_date(params[:opened_to])
  end

  def closed_from
    @closed_from ||= parse_date(params[:closed_from])
  end

  def closed_to
    @closed_to ||= parse_date(params[:closed_to])
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end
end
