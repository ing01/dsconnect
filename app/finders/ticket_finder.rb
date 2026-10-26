# The filter set behind the Kanban's quick search and the "Busca detalhada"
# form. Extracted from TicketsController, which had grown to carry the whole
# query language alongside a dozen actions.
class TicketFinder
  # Params that map directly onto an equality filter on `tickets`.
  # Aceitam tanto um valor quanto uma lista: `where(coluna => [a, b])` vira um
  # IN, que e o "ou" dentro de um mesmo filtro. Entre filtros diferentes segue
  # valendo "e", porque cada um encadeia outro `where`.
  DIRECT_ATTRIBUTE_FILTERS = {
    ticket_column_id: :ticket_column_id,
    team_id: :team_id,
    status: :status,
    priority: :priority,
    ticket_category_id: :ticket_category_id,
    ticket_complexity_id: :ticket_complexity_id,
    sprint_id: :sprint_id,
    display_id: :display_id
  }.freeze

  # Empresa reads the ticket's own `company_id`; Contato still has no dedicated
  # FK (a ticket only knows its requester through whichever Conversation(s) are
  # linked to it) and keeps joining through
  # `ticket_conversations -> conversations -> contact`.
  CONTACT_FILTER_PARAMS = [:contact_id, :contact_query].freeze
  COMPANY_FILTER_PARAMS = [:company_id, :company_query].freeze

  pattr_initialize [:scope!, :params!, :current_user!]

  def perform
    result = filter_by_ownership(scope)
    result = filter_by_attributes(result)
    result = filter_by_sprint(result)
    result = filter_by_parent(result)
    result = filter_by_finalized_stage(result)
    result = filter_by_conversation(result)
    result = filter_by_contact(result)
    result = filter_by_impediment(result)
    result = filter_by_triage(result)
    filter_by_date_and_text(result)
  end

  private

  def filter_by_ownership(relation)
    return relation.where(assignee_id: current_user.id) if params[:mine].present?
    return relation.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?

    relation
  end

  # Impedimento e um eixo proprio, ao lado do status: um ticket impedido
  # continua aberto. O filtro apenas recorta - nao mexe em `status` nem
  # substitui nenhum dos filtros existentes.
  #
  # Ausente o parametro, a listagem nao muda em nada: e assim que o Kanban e
  # a Busca detalhada seguem se comportando como sempre.
  # A fila de triagem: os chamados abertos pelo cliente que ainda nao foram
  # aceitos. Ausente, a listagem se comporta como sempre - ela nao exclui os
  # pendentes, porque a Busca detalhada procura em tudo.
  def filter_by_triage(relation)
    return relation if params[:pending_triage].nil? || params[:pending_triage] == ''

    ActiveModel::Type::Boolean.new.cast(params[:pending_triage]) ? relation.pending_triage : relation.triaged
  end

  def filter_by_impediment(relation)
    # `false.blank?` e true no Rails, entao `blank?` aqui descartaria um pedido
    # explicito por NAO impedidos. So a ausencia do parametro desliga o filtro.
    return relation if params[:blocked].nil? || params[:blocked] == ''

    ActiveModel::Type::Boolean.new.cast(params[:blocked]) ? relation.blocked : relation.not_blocked
  end

  def filter_by_attributes(relation)
    DIRECT_ATTRIBUTE_FILTERS.each do |param, column|
      relation = relation.where(column => params[param]) if params[param].present?
    end
    relation = relation.where('tickets.title ILIKE :q', q: "%#{params[:title]}%") if params[:title].present?
    relation
  end

  # O Backlog do Modulo de Desenvolvimento: tickets da Mesa sem sprint. Nao
  # entra em DIRECT_ATTRIBUTE_FILTERS porque "nenhum sprint" nao e um valor
  # para comparar - e a ausencia de um.
  def filter_by_sprint(relation)
    return relation if params[:without_sprint].blank?

    ActiveModel::Type::Boolean.new.cast(params[:without_sprint]) ? relation.where(sprint_id: nil) : relation
  end

  # O Backlog do Modulo de Desenvolvimento so' lista ticket FILHO - o time de
  # suporte abre o chamado (o pai, com prints e detalhes) e e' da aba
  # "Desenvolvimento" dele que nasce o ticket que vai pro Backlog. Um ticket
  # sem pai nesta Mesa nao veio desse fluxo, entao nao aparece la'.
  def filter_by_parent(relation)
    return relation if params[:with_parent].blank?

    ActiveModel::Type::Boolean.new.cast(params[:with_parent]) ? relation.where.not(parent_id: nil) : relation
  end

  # Idem, pro Estagio: uma vez no Estagio final da Mesa (`kind: completed`,
  # o "Concluido" do fluxo), o ticket sai da listagem do Backlog - ele
  # continua existindo e acessivel pelo numero/Busca detalhada, so' nao
  # ocupa mais espaco ali.
  def filter_by_finalized_stage(relation)
    return relation if params[:exclude_finalized_stage].blank?
    return relation unless ActiveModel::Type::Boolean.new.cast(params[:exclude_finalized_stage])

    relation.joins(:ticket_column).where.not(ticket_columns: { kind: 'completed' })
  end

  def filter_by_conversation(relation)
    return relation if params[:conversation_id].blank?

    relation.joins(:ticket_conversations).where(ticket_conversations: { conversation_id: params[:conversation_id] })
  end

  def filter_by_contact(relation)
    relation = filter_by_company(relation)
    return relation if CONTACT_FILTER_PARAMS.none? { |param| params[param].present? }

    relation = relation.joins(ticket_conversations: { conversation: :contact })
    relation = relation.where(contacts: { id: params[:contact_id] }) if params[:contact_id].present?
    relation = relation.where('contacts.name ILIKE :q', q: "%#{params[:contact_query]}%") if params[:contact_query].present?
    relation.distinct
  end

  def filter_by_company(relation)
    return relation if COMPANY_FILTER_PARAMS.none? { |param| params[param].present? }

    relation = relation.where(tickets: { company_id: params[:company_id] }) if params[:company_id].present?
    relation = relation.joins(:company).where('companies.name ILIKE :q', q: "%#{params[:company_query]}%") if params[:company_query].present?
    relation
  end

  def filter_by_date_and_text(relation)
    relation = filter_by_dates(relation)
    return relation if params[:q].blank?

    # Matches the ticket number and the title; the Kanban's quick search sends
    # one string for both.
    relation.where('tickets.title ILIKE :q OR CAST(tickets.display_id AS TEXT) ILIKE :q', q: "%#{params[:q]}%")
  end

  def filter_by_dates(relation)
    relation = relation.where('tickets.created_at >= ?', params[:created_after].to_date.beginning_of_day) if params[:created_after].present?
    # `created_before` is a plain "YYYY-MM-DD" (a calendar day, e.g. "today" in
    # the Busca detalhada defaults) - comparing with `<=` against that bare date
    # would cast to midnight and silently exclude every ticket created later
    # that same day, so the upper bound is the end of the day.
    relation = relation.where('tickets.created_at <= ?', params[:created_before].to_date.end_of_day) if params[:created_before].present?
    relation
  end
end
