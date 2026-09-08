# Porta o ranking por implantador e a seção "capacidade da equipe" do painel.
# Capacidade é period-independent (descreve a carteira ativa atual), mesma
# exceção documentada no painel - por isso usa `period_independent_projects`.
class V2::Reports::Implementation::ImplementerReportBuilder < V2::Reports::Implementation::BaseBuilder
  def build
    {
      by_implementer: rollup(filtered_projects),
      capacity: rollup(period_independent_projects.select { |project| project.status == 'active' && project.stage != 'finalizado' })
    }
  end

  private

  def rollup(projects)
    projects.group_by(&:implementer).map do |implementer, group|
      {
        implementer_id: implementer&.id,
        implementer_name: implementer&.name,
        projects_count: group.size,
        by_stage: group.group_by(&:stage).transform_values(&:count),
        total_hours: group.sum { |project| hours_for(project) }
      }
    end.sort_by { |row| -row[:projects_count] }
  end
end
