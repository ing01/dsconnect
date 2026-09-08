# Porta o score de complexidade do painel: `horas + módulos×2 + ticketsPos×3`
# (pesos arbitrários, só um ponto de partida objetivo pra "quais clientes
# deram mais trabalho", documentado assim desde o painel original).
#
# O termo "módulos×2" não tem como sobreviver igual: painel permitia vários
# módulos por cliente numa linha só, aqui um Project tem exatamente 1 módulo
# (ver decisão D8 do plano). O proxy que sobra é "quantos outros projetos essa
# mesma empresa tem" - mede a mesma ideia (quantas frentes esse cliente tem
# abertas), mas é uma reinterpretação, não uma tradução direta da fórmula.
class V2::Reports::Implementation::ComplexityScoreBuilder < V2::Reports::Implementation::BaseBuilder
  SIBLING_WEIGHT = 2
  POS_TICKETS_WEIGHT = 3

  def build
    projects = filtered_projects
    sibling_counts = projects.group_by(&:company_id).transform_values(&:count)

    projects.map do |project|
      siblings = project.company_id ? (sibling_counts[project.company_id] - 1) : 0
      score = hours_for(project) + (siblings * SIBLING_WEIGHT) + (pos_tickets_count_for(project) * POS_TICKETS_WEIGHT)

      { project_id: project.id, project_name: project.name, score: score.round(1) }
    end.sort_by { |row| -row[:score] }
  end
end
