# Porta a distribuição por módulo do painel (% de CLIENTES por módulo, não
# horas - não dava pra calcular horas por módulo lá). Aqui expõe total_hours
# também, já que o Duesoft permite calcular isso (Project tem 1 módulo só,
# então basta somar as horas dos projetos daquele módulo) - é um extra que o
# painel nunca teve.
class V2::Reports::Implementation::ModuleReportBuilder < V2::Reports::Implementation::BaseBuilder
  def build
    projects = filtered_projects
    total = projects.size

    projects.group_by(&:project_module).map do |project_module, group|
      {
        project_module_id: project_module&.id,
        project_module_name: project_module&.name,
        projects_count: group.size,
        percentage: total.zero? ? 0 : (group.size.to_f / total * 100).round(1),
        total_hours: group.sum { |project| hours_for(project) }
      }
    end.sort_by { |row| -row[:projects_count] }
  end
end
