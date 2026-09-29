# O relatorio de tickets: uma linha por ticket, filtravel por cliente, status,
# responsavel, catalogo e periodo de abertura/fechamento.
#
# Somente leitura - le a mesma tabela que o board ja usa, sem estado proprio.
class Api::V1::Accounts::TicketReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @rows = Tickets::TicketReportBuilder.new(account: Current.account, params: report_params).perform
  end

  private

  # Ler o relatorio e ver a mesma lista de tickets que o board ja mostra a
  # qualquer agente - so' organizada em tabela e filtravel por cliente.
  def check_authorization
    authorize(Ticket)
  end

  def report_params
    params.permit(:company_id, :status, :assignee_id, :service_catalog_id,
                  :opened_from, :opened_to, :closed_from, :closed_to)
  end
end
