# Porta o gráfico "clientes × horas por mês" do painel: sempre os últimos
# MONTHS_BACK meses, ignorando o filtro de período (exceção documentada no
# painel, pra permitir comparação mês a mês) - mas respeitando os outros
# filtros (implantador/módulo/mesa/estágio/busca).
class V2::Reports::Implementation::MonthlyReportBuilder < V2::Reports::Implementation::BaseBuilder
  MONTHS_BACK = 6

  def build
    projects = period_independent_projects

    months.map do |month_start|
      month_range = month_start.all_month
      {
        month: month_start.strftime('%Y-%m'),
        clients_started: projects.count { |project| project.start_date.present? && month_range.cover?(project.start_date) },
        hours_logged: hours_logged_in(projects, month_range)
      }
    end
  end

  private

  def months
    (0...MONTHS_BACK).map { |i| Date.current.beginning_of_month - i.months }.reverse
  end

  def hours_logged_in(projects, month_range)
    projects.sum do |project|
      project.tickets.sum do |ticket|
        ticket.ticket_time_entries.sum { |entry| month_range.cover?(entry.worked_on) ? entry.hours : 0 }
      end
    end
  end
end
