# Porta `classificarIncidencia`/`buildIncidenciaRanking` do painel: contagem de
# tickets "no pós" por cliente, classificada em faixas. Thresholds nomeados
# pra facilitar ajuste futuro, mesmos valores do painel.
class V2::Reports::Implementation::IncidenceReportBuilder < V2::Reports::Implementation::BaseBuilder
  INCIDENCE_THRESHOLDS = { 'normal' => 0..3, 'atencao' => 4..7, 'alto' => 8..12 }.freeze
  CRITICAL_LABEL = 'critico'.freeze

  def build
    filtered_projects.select { |project| POS_STAGES.include?(project.stage) }.map do |project|
      count = pos_tickets_count_for(project)

      {
        project_id: project.id,
        project_name: project.name,
        company_name: project.company&.name,
        tickets_count: count,
        reincidente: count > 1,
        classification: classify(count)
      }
    end.sort_by { |row| -row[:tickets_count] }
  end

  private

  def classify(count)
    INCIDENCE_THRESHOLDS.each { |label, range| return label if range.cover?(count) }
    CRITICAL_LABEL
  end
end
