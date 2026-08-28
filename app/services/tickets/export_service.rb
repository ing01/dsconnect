# Os dados da exportacao da Busca detalhada.
#
# Usa o mesmo TicketFinder da tela, com os mesmos parametros: o arquivo traz
# exatamente o que a busca mostrou. Duplicar a logica dos filtros aqui faria o
# relatorio divergir da tela no primeiro filtro novo que alguem criasse.
#
# A paginacao fica de fora de proposito - ela e da tela, nao do arquivo.
class Tickets::ExportService
  # Um teto para nao montar um arquivo que nenhum programa abre e que derruba o
  # processo pelo caminho. Acima disso, o pedido e recusado com uma mensagem que
  # diz o que fazer.
  MAX_ROWS = 10_000

  class TooManyRows < StandardError; end

  COLUMNS = [
    { key: :display_id, label: 'Numero' },
    { key: :created_at, label: 'Criado em' },
    { key: :title, label: 'Titulo' },
    { key: :company, label: 'Empresa' },
    { key: :contact, label: 'Solicitante' },
    { key: :assignee, label: 'Atendente' },
    { key: :team, label: 'Mesa de Servico' },
    { key: :column, label: 'Estagio' },
    { key: :status, label: 'Status' },
    { key: :priority, label: 'Prioridade' },
    { key: :category, label: 'Categoria' },
    { key: :closed_at, label: 'Fechado em' }
  ].freeze

  pattr_initialize [:account!, :user!, :params!]

  def count
    @count ||= scope.count
  end

  # Percorre em lotes: um relatorio grande nunca fica inteiro na memoria.
  def each_row
    return to_enum(:each_row) unless block_given?

    raise TooManyRows if count > MAX_ROWS

    scope.includes(:team, :ticket_column, :ticket_category, :assignee, :company, :contact)
         .order(created_at: :desc)
         .find_each(batch_size: 500) { |ticket| yield row_for(ticket) }
  end

  def headers
    COLUMNS.pluck(:label)
  end

  # De qual tabela vem o nome de cada filtro escolhido, para o cabecalho do
  # relatorio impresso.
  NAMED_FILTERS = [
    ['Empresa', :company_id, -> { Company }],
    ['Solicitante', :contact_id, -> { Contact }],
    ['Atendente', :assignee_id, -> { User }],
    ['Mesa de Servico', :team_id, -> { Team }],
    ['Estagio', :ticket_column_id, -> { TicketColumn }],
    ['Categoria', :ticket_category_id, -> { TicketCategory }]
  ].freeze

  # Os filtros em texto. So o que foi de fato preenchido aparece.
  def applied_filters
    ([period_line] + named_lines + translated_lines + text_lines).compact
  end

  private

  def scope
    @scope ||= TicketFinder.new(
      scope: account.tickets, params: params, current_user: user
    ).perform
  end

  # Uma funcao por coluna, na mesma ordem de COLUMNS: a linha sai da tabela, e
  # nao de doze atribuicoes que podem sair de ordem.
  VALUES = {
    display_id: ->(ticket, _s) { ticket.display_id },
    created_at: ->(ticket, service) { service.send(:local_time, ticket.created_at) },
    title: ->(ticket, _s) { ticket.title },
    company: ->(ticket, _s) { ticket.company&.name },
    contact: ->(ticket, _s) { ticket.requester_contact&.name },
    assignee: ->(ticket, _s) { ticket.assignee&.name },
    team: ->(ticket, _s) { ticket.team&.name&.titleize },
    column: ->(ticket, _s) { ticket.ticket_column&.name },
    # Rotulos, e nao os valores internos: ninguem le "open" num relatorio.
    status: ->(ticket, service) { service.send(:translate, :status, ticket.status) },
    priority: ->(ticket, service) { service.send(:translate, :priority, ticket.priority) },
    category: ->(ticket, _s) { ticket.ticket_category&.name },
    closed_at: ->(ticket, service) { service.send(:local_time, ticket.closed_at) }
  }.freeze

  def row_for(ticket)
    VALUES.transform_values { |value| value.call(ticket, self) }
  end

  def local_time(time)
    return if time.blank?

    time.in_time_zone(account.reporting_timezone.presence || 'UTC').strftime('%d/%m/%Y %H:%M')
  end

  def translate(kind, value)
    return if value.blank?

    I18n.t("ticket.#{kind}.#{value}", default: value.to_s.humanize)
  end

  def translated_list(param)
    Array(params[param]).filter_map { |value| translate(param, value) }
  end

  def period_line
    from = params[:created_after].presence
    to = params[:created_before].presence
    return if from.blank? && to.blank?

    "Periodo: #{format_date(from) || '...'} ate #{format_date(to) || '...'}"
  end

  def format_date(value)
    Date.parse(value).strftime('%d/%m/%Y')
  rescue StandardError
    nil
  end

  def named_lines
    NAMED_FILTERS.map do |label, param, model|
      names_line(label, model.call.where(id: params[param]).pluck(:name))
    end
  end

  def translated_lines
    [
      names_line('Status', translated_list(:status)),
      names_line('Prioridade', translated_list(:priority))
    ]
  end

  def text_lines
    [text_line('Numero', params[:display_id]), text_line('Titulo', params[:title])]
  end

  def names_line(label, names)
    return if names.blank?

    "#{label}: #{names.join(', ')}"
  end

  def text_line(label, value)
    return if value.blank?

    "#{label}: #{value}"
  end
end
