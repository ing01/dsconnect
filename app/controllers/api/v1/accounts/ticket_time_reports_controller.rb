# O relatorio de apontamentos de tickets.
#
# Somente leitura e sem estado proprio: soma os TicketTimeEntry que a aba do
# ticket ja grava. Todos os filtros sao opcionais - periodo, Mesa, nivel,
# usuario e categoria - e se acumulam.
class Api::V1::Accounts::TicketTimeReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @report = Tickets::TimeEntriesReportBuilder.new(
      account: Current.account, params: report_params
    ).perform
  end

  private

  # Ler o relatorio e ver o mesmo que a lista de tickets ja mostra, agregado.
  def check_authorization
    authorize(Ticket)
  end

  def report_params
    params.permit(:from, :to, :team_id, :level, :user_id, :category, :company_id)
  end
end
