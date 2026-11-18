# O relatorio "Chat detalhado": uma linha por conversa (chat), com quem atendeu,
# quanto esperou, quanto durou, o ticket vinculado e a avaliacao - mais um resumo
# com os indicadores do periodo.
#
# Somente leitura: nao grava nada, so le Conversation, Message, CsatSurveyResponse e
# os tickets ligados. Os filtros se acumulam e todos sao opcionais.
#
# Esta classe cuida da CONSULTA (filtros, lotes, fatos que nao estao na conversa); quem
# transforma cada conversa em linha e' o ChatDetailReport::EntryBuilder, e quem soma o
# resumo e' o ChatDetailReport::SummaryAccumulator.
class ChatDetailReport::Builder
  # Um teto para nao montar uma consulta que derrube o servidor: acima disso o pedido e
  # recusado dizendo para estreitar o periodo.
  MAX_ROWS = 20_000
  BATCH_SIZE = 500

  class TooManyRows < StandardError; end

  # chave da linha => rotulo da coluna (a ordem e a da planilha).
  COLUMNS = [
    [:id, 'ID'], [:client, 'Cliente'], [:origin, 'Origem'], [:started_by, 'Iniciado por'],
    [:started_at, 'Iniciado em'], [:assumed_at, 'Assumido em'], [:first_message_at, 'Primeira mensagem enviada'],
    [:updated_at, 'Atualizado em'], [:finished_at, 'Finalizado em'], [:duration, 'Duração'],
    [:wait, 'Tempo de espera'], [:assignee, 'Responsável'], [:group, 'Grupo de atendente'],
    [:department, 'Departamento'], [:contact, 'Conversado com'], [:status, 'Status'], [:phone, 'Telefone'],
    [:rating, 'Avaliação'], [:catalog, 'Catálogo de serviços'], [:area, 'Área do catálogo'],
    [:item, 'Item do Catálogo'], [:ticket, 'Ticket']
  ].freeze

  SUMMARY_COLUMNS = [
    [:attended, 'Chats atendidos'], [:linked_tickets, 'Tickets vinculados'],
    [:first_contact, 'Resolvidos no primeiro contato'], [:average_duration, 'Média de atendimento'],
    [:contacts, 'Solicitantes e contatos atendidos'], [:average_wait, 'Média de espera'],
    [:total_time, 'Tempo total de chat'], [:cancelled, 'Chats cancelados']
  ].freeze

  # Textos das mensagens de sistema que dizem "foi atribuido": a atribuicao nao tem
  # coluna propria, so' esse registro na conversa (ver AssigneeActivityMessageHandler).
  ASSIGNMENT_KEYS = %w[conversations.activity.assignee.assigned conversations.activity.assignee.self_assigned].freeze

  FILTER_COLUMNS = %i[assignee_id team_id inbox_id queue_id].freeze

  INCLUDES = [
    { inbox: :channel }, { contact: :company }, :assignee, :team, :queue, :csat_survey_response,
    { tickets: { service_catalog_item: { service_catalog_area: :service_catalog } } }
  ].freeze

  pattr_initialize [:account!, :params!]

  def self.headers
    COLUMNS.map(&:last)
  end

  def total
    ids.size
  end

  # Percorre em lotes: nunca ha mais que BATCH_SIZE conversas na memoria.
  def each_entry(&block)
    return to_enum(:each_entry) unless block

    raise TooManyRows if total > MAX_ROWS

    ids.each_slice(BATCH_SIZE) { |slice| entries_for(slice).each(&block) }
  end

  # Uma pagina das linhas + o resumo do periodo inteiro, numa passada so'.
  def page(page:, per_page:)
    first = (page - 1) * per_page
    rows = []
    summary = ChatDetailReport::SummaryAccumulator.new
    each_entry.with_index do |entry, index|
      summary.add(entry)
      rows << entry.row if index >= first && index < first + per_page
    end
    { rows: rows, summary: summary.to_h, total: total }
  end

  def summary
    ChatDetailReport::SummaryAccumulator.new.tap { |accumulator| each_entry { |entry| accumulator.add(entry) } }.to_h
  end

  private

  def scope
    @scope ||= apply_filters(account.conversations)
  end

  def apply_filters(relation)
    relation = relation.where(created_at: period) if period
    FILTER_COLUMNS.each { |key| relation = relation.where(key => params[key]) if params[key].present? }
    relation = relation.where(status: params[:status]) if Conversation.statuses.key?(params[:status].to_s)
    return relation if params[:company_id].blank?

    relation.joins(:contact).where(contacts: { company_id: params[:company_id] })
  end

  def ids
    @ids ||= scope.reorder(created_at: :desc, id: :desc).pluck(:id)
  end

  def period
    from = parse_date(params[:from])&.beginning_of_day
    to = parse_date(params[:to])&.end_of_day
    return if from.blank? && to.blank?

    (from || Time.zone.at(0))..(to || Time.zone.now)
  end

  def parse_date(value)
    return if value.blank?

    zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def zone
    @zone ||= ActiveSupport::TimeZone[account.reporting_timezone.presence || 'UTC'] || Time.zone
  end

  def entries_for(slice)
    conversations = Conversation.where(id: slice).includes(*INCLUDES).index_by(&:id)
    facts = { first_messages: first_messages(slice), assignments: assignments(slice) }
    builder = ChatDetailReport::EntryBuilder.new(zone: zone, facts: facts)
    slice.filter_map { |id| conversations[id] && builder.build(conversations[id]) }
  end

  # Quem escreveu a primeira mensagem de cada conversa - uma consulta por lote, e nao
  # uma por conversa.
  def first_messages(slice)
    Message.where(conversation_id: slice, message_type: [0, 1], private: false)
           .select('DISTINCT ON (conversation_id) conversation_id, message_type, sender_type')
           .reorder(:conversation_id, :created_at)
           .index_by(&:conversation_id)
  end

  # Quando cada conversa foi atribuida pela primeira vez e quantas vezes.
  def assignments(slice)
    return {} if assignment_patterns.blank?

    Message.where(conversation_id: slice, message_type: 2)
           .where(assignment_patterns.map { 'content ILIKE ?' }.join(' OR '), *assignment_patterns)
           .reorder(nil)
           .group(:conversation_id)
           .pluck(:conversation_id, Arel.sql('MIN(created_at)'), Arel.sql('COUNT(*)'))
           .to_h { |conversation_id, first, count| [conversation_id, { first: first, count: count }] }
  end

  # "Atribuído a %{assignee_name} por %{user_name}" vira "Atribuído a % por %": o modelo
  # do I18n, nos idiomas em que a conta pode ter conversado, com os campos como curinga.
  def assignment_patterns
    @assignment_patterns ||= %i[pt_BR en].flat_map do |locale|
      ASSIGNMENT_KEYS.filter_map do |key|
        I18n.t(key, locale: locale, default: nil, assignee_name: '%', user_name: '%').to_s.presence
      end
    end.uniq
  end
end
