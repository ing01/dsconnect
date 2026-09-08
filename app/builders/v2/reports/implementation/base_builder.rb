class V2::Reports::Implementation::BaseBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :params!]

  # A ticket only counts as "no pós" via the *project's current stage* - tickets
  # have no flag of their own for this, same approximation painel used
  # (fase do cliente, não do ticket).
  POS_STAGES = %w[acompanhamento pos].freeze

  private

  # `params[:date_field]` lets the caller choose which Project date the period
  # filter pivots on - same idea as painel's own "campo de data" filter.
  # `start_date` (previsão de início) is the default.
  DATE_FIELDS = %w[start_date due_date support_ends_on].freeze

  def date_field
    field = params[:date_field].to_s
    DATE_FIELDS.include?(field) ? field : 'start_date'
  end

  # Every filter except the period one - reused as-is by the two reports
  # painel documented as period-independent (gráfico mensal, capacidade).
  def scoped_projects
    projects = account.projects
    projects = projects.where(implementer_id: params[:implementer_id]) if params[:implementer_id].present?
    projects = projects.where(project_module_id: params[:project_module_id]) if params[:project_module_id].present?
    projects = projects.where(team_id: params[:team_id]) if params[:team_id].present?
    projects = projects.where(stage: params[:stage]) if params[:stage].present?

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      projects = projects.left_joins(:company).where(
        'LOWER(projects.name) LIKE :term OR LOWER(companies.name) LIKE :term', term: term
      )
    end

    projects
  end

  def date_filtered(relation)
    return relation unless range

    relation.where(date_field => range.begin..range.end)
  end

  def preload(relation)
    relation.includes(:implementer, :company, :project_module, tickets: :ticket_time_entries).to_a
  end

  # Every project matching the filters, period included - what most reports use.
  def filtered_projects
    @filtered_projects ||= preload(date_filtered(scoped_projects))
  end

  # Same filters, period excluded - for the two period-independent reports.
  def period_independent_projects
    @period_independent_projects ||= preload(scoped_projects)
  end

  def hours_for(project)
    project.tickets.sum { |ticket| ticket.ticket_time_entries.sum(&:hours) }
  end

  def hours_by_category_for(project)
    entries = project.tickets.flat_map(&:ticket_time_entries)
    entries.group_by(&:category).transform_values { |group| group.sum(&:hours) }
  end

  def pos_tickets_count_for(project)
    return 0 unless POS_STAGES.include?(project.stage)

    project.tickets.size
  end
end
