# Para onde um chamado do Portal do Cliente entra: mesma regra usada hoje na
# abertura pelo formulario (`Api::V1::Client::TicketsController`) e, agora,
# pela triagem via IA (`Captain::Tools::CreateTicketFromTriageTool`) - extraida
# para nao duplicar a logica de roteamento por Empresa/Categoria nos dois
# lugares.
class Tickets::PortalRoutingService
  def initialize(account:, company_id: nil, category: nil)
    @account = account
    @company_id = company_id
    @category = category
  end

  def resolve
    team = resolved_team

    {
      team: team,
      ticket_column: entry_column(team),
      ticket_category: resolved_category(team)
    }
  end

  private

  def resolved_team
    routing_rule&.team || @category&.team || client_teams.first
  end

  # A regra de roteamento por Empresa decide a Mesa, nao a Categoria - uma
  # Categoria de outra Mesa nao sobrevive a troca (`ticket_category_belongs_to_team`).
  def resolved_category(team)
    category = routing_rule.present? && @category&.team_id != team&.id ? nil : @category
    category || default_category(team)
  end

  def routing_rule
    return @routing_rule if defined?(@routing_rule)

    @routing_rule = begin
      next_rule = nil
      if @company_id.present?
        company = Company.find_by(id: @company_id, account_id: @account.id)
        next_rule = @account.ticket_routing_rules.find_by(client_level: company.client_level) if company.present?
      end
      next_rule
    end
  end

  def client_teams
    @account.teams.active.visible_in_portal.order(:name)
  end

  def entry_column(team)
    return nil if team.blank?

    team.ticket_columns.find_by(kind: 'pending') || team.ticket_columns.order(:position, :id).first
  end

  def default_category(team)
    return nil if team.blank?

    team.ticket_categories.client_visible.first || team.ticket_categories.order(:position, :id).first
  end
end
