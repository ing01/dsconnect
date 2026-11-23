# Atribui o assignee dos tickets da mesa "Especialista" ao analista responsavel
# pelo nicho/sub-nicho da empresa do ticket (ver UserCompanyNiche/UserCompanySubNiche).
#
# Sobrescreve o assignee atual sempre que acha exatamente um analista responsavel.
# Pula e reporta (nada e chutado) quando: o ticket nao tem empresa vinculada, a
# empresa nao tem nicho nem sub-nicho cadastrado, nenhum analista e responsavel por
# aquele nicho/sub-nicho, ou mais de um analista e (niche e sub_niche apontando
# para analistas diferentes, por exemplo).
class Tickets::SpecialistDeskNicheAssigner
  TEAM_NAME = 'Especialista'.freeze

  Report = Struct.new(
    :team_missing, :assigned, :unchanged, :skipped_no_company,
    :skipped_no_niche, :skipped_no_responsible, :skipped_ambiguous, :skipped_finalized,
    keyword_init: true
  )

  def initialize(account, dry_run: false)
    @account = account
    @dry_run = dry_run
  end

  def perform
    report = Report.new(
      team_missing: false, assigned: [], unchanged: [], skipped_no_company: [],
      skipped_no_niche: [], skipped_no_responsible: [], skipped_ambiguous: [], skipped_finalized: []
    )

    team = @account.teams.find_by('name ILIKE ?', TEAM_NAME)
    if team.nil?
      report.team_missing = true
      return report
    end

    team.tickets.includes(:company).find_each { |ticket| process(ticket, report) }
    report
  end

  private

  def process(ticket, report)
    return report.skipped_finalized << ticket.id if ticket.finalized?

    company = ticket.company
    return report.skipped_no_company << ticket.id if company.nil?

    responsible = responsible_for(company)
    case responsible
    when :none then report.skipped_no_niche << ticket.id
    when :ambiguous then report.skipped_ambiguous << ticket.id
    when nil then report.skipped_no_responsible << ticket.id
    else assign(ticket, responsible, report)
    end
  end

  def assign(ticket, responsible, report)
    if ticket.assignee_id == responsible.id
      report.unchanged << ticket.id
      return
    end

    ticket.update!(assignee_id: responsible.id) unless @dry_run
    report.assigned << [ticket.id, responsible.name]
  end

  # :none = empresa sem nicho/sub-nicho cadastrado; nil = cadastrado mas sem
  # analista responsavel; :ambiguous = mais de um analista responsavel.
  def responsible_for(company)
    return :none if company.company_niche_id.blank? && company.company_sub_niche_id.blank?

    user_ids = Set.new
    if company.company_niche_id.present?
      user_ids.merge(UserCompanyNiche.where(company_niche_id: company.company_niche_id).pluck(:user_id))
    end
    if company.company_sub_niche_id.present?
      user_ids.merge(UserCompanySubNiche.where(company_sub_niche_id: company.company_sub_niche_id).pluck(:user_id))
    end

    return nil if user_ids.empty?
    return :ambiguous if user_ids.size > 1

    User.find(user_ids.first)
  end
end
