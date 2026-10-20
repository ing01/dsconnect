# O relatorio de SLA por agente e por Cliente.
#
# Somente leitura e sem estado proprio: soma os TicketAppliedSla que o proprio
# ticket ja mantem. Todos os filtros sao opcionais - periodo, Mesa, Cliente,
# responsavel e tipo de relogio - e se acumulam.
class Api::V1::Accounts::TicketSlaReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @report = Tickets::SlaByAgentReportBuilder.new(
      account: Current.account, params: report_params
    ).perform
  end

  private

  # Mesmo criterio do relatorio de horas: ler o relatorio e ver o mesmo que a
  # lista de tickets ja mostra, agregado.
  def check_authorization
    authorize(Ticket)
  end

  def report_params
    params.permit(:from, :to, :team_id, :kind, :company_id)
  end
end
