# Porta o `totalHoras` do painel: soma das 3 categorias de TicketTimeEntry
# (implantacao/desenvolvimento/dev_geral) para os projetos filtrados.
class V2::Reports::Implementation::HoursSummaryBuilder < V2::Reports::Implementation::BaseBuilder
  def build
    by_category = TicketTimeEntry::CATEGORIES.index_with { |category| 0.0 }

    filtered_projects.each do |project|
      hours_by_category_for(project).each { |category, hours| by_category[category] += hours }
    end

    {
      total_hours: by_category.values.sum,
      by_category: by_category,
      projects_count: filtered_projects.size
    }
  end
end
