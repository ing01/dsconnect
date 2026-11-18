# A planilha COMPLETA da Busca detalhada: uma linha por ticket, com TUDO o que o
# ticket guarda - as colunas do cadastro, as pessoas, as datas, o impedimento, os
# campos do desenvolvimento e o resumo do que esta ligado a ele (anexos,
# comunicacoes, comentarios, apontamentos...). Campo nao preenchido sai VAZIO.
#
# So' o Excel usa esta planilha. O PDF continua com o resumo de doze colunas
# (Tickets::ExportService::COLUMNS): sessenta colunas nao cabem numa pagina.
#
# Cada coluna e' um par rotulo + funcao, na ordem em que aparece: a linha sai da
# tabela, e nao de dezenas de atribuicoes que poderiam sair fora de ordem.
class Tickets::Export::FullSheet
  Column = Struct.new(:label, :value)

  # Uma celula do Excel guarda no maximo 32.767 caracteres; acima disso o arquivo
  # fica corrompido. Texto maior e' cortado, com a marca de que foi.
  CELL_LIMIT = 32_000

  # Tudo o que as colunas leem, carregado em lote: sem isto cada ticket dispararia
  # dezenas de consultas.
  INCLUDES = [
    :team, :ticket_column, :ticket_category, :ticket_complexity, :company, :contact,
    :parent, :children, :merged_into, :merged_tickets, :project, :project_task_template, :sprint,
    :blocked_by, :blocked_by_child, :triaged_by, :followers, { conversations: :contact },
    :ticket_customer_communications, { ticket_comments: :user }, { ticket_time_entries: :user }, :ticket_checklist_items,
    :calendar_events, :ticket_proposals, :ticket_applied_slas,
    { service_catalog_item: { service_catalog_area: :service_catalog } },
    { ticket_attachments: { file_attachment: :blob } },
    { ticket_activities: :user },
    *AssigneeLeveled.assignee_associations
  ].freeze

  DEVELOPMENT_TYPES = { 'bug' => 'Bug', 'task' => 'Tarefa', 'story' => 'História' }.freeze

  # Os campos do card do Jira, guardados em custom_attributes.
  DEV_FIELDS = {
    'observacoes_dev' => 'Observações do desenvolvedor',
    'observacoes_teste' => 'Observações sobre o teste',
    'documentacao' => 'Documentação',
    'instrucoes' => 'Instruções',
    'analise' => 'Análise'
  }.freeze

  def self.columns
    @columns ||= Tickets::Export::FullSheetColumns.all.freeze
  end

  def self.headers
    columns.map(&:label)
  end

  def initialize(account:)
    @account = account
  end

  def row(ticket)
    self.class.columns.map { |column| clip(column.value.call(ticket, self)) }
  end

  # --- Ajudantes das colunas (publicos porque as funcoes de coluna os chamam) ---

  def text(value)
    value.to_s.presence
  end

  def yes_no(value)
    value ? 'Sim' : 'Não'
  end

  def time(value)
    return if value.blank?

    value.in_time_zone(timezone).strftime('%d/%m/%Y %H:%M')
  end

  def label(kind, value)
    return if value.blank?

    I18n.t("ticket.#{kind}.#{value}", default: value.to_s.humanize)
  end

  def number(ticket)
    ticket ? "##{ticket.display_id}" : nil
  end

  def numbers(tickets)
    tickets.map { |ticket| number(ticket) }.join('; ').presence
  end

  def other_custom_attributes(ticket)
    extras = ticket.custom_attributes.to_h.except('imported_ticket_number', *DEV_FIELDS.keys)
    extras.map { |key, value| "#{key}: #{value}" }.join('; ').presence
  end

  def attachment_names(ticket)
    ticket.ticket_attachments.filter_map { |item| item.file.filename.to_s if item.file.attached? }.join('; ').presence
  end

  def communications(ticket)
    lines = ticket.ticket_customer_communications.sort_by(&:created_at).map do |item|
      sentido = item.direction == 'inbound' ? 'Cliente' : 'Equipe'
      "[#{time(item.sent_at || item.created_at)}] #{sentido}: #{item.subject} - #{item.body}"
    end
    lines.join("\n").presence
  end

  def comments(ticket)
    lines = ticket.ticket_comments.sort_by(&:created_at).map do |item|
      "[#{time(item.created_at)}] #{item.user&.name}: #{item.content}"
    end
    lines.join("\n").presence
  end

  def hours(ticket)
    total = ticket.ticket_time_entries.sum { |entry| entry.hours.to_f }
    total.zero? ? nil : total.round(2)
  end

  def time_entries(ticket)
    lines = ticket.ticket_time_entries.sort_by { |entry| [entry.worked_on, entry.id] }.map do |entry|
      "#{entry.worked_on&.strftime('%d/%m/%Y')} #{entry.user&.name}: #{entry.hours}h (#{entry.category})#{" - #{entry.note}" if entry.note.present?}"
    end
    lines.join("\n").presence
  end

  def checklist_progress(ticket)
    items = ticket.ticket_checklist_items
    return if items.empty?

    "#{items.count(&:completed)}/#{items.size}"
  end

  def checklist_items(ticket)
    ticket.ticket_checklist_items.map { |item| "[#{item.completed ? 'x' : ' '}] #{item.title}" }.join("\n").presence
  end

  def appointments(ticket)
    lines = ticket.calendar_events.sort_by(&:start_at).map { |event| "#{time(event.start_at)} - #{time(event.end_at)}: #{event.title}" }
    lines.join("\n").presence
  end

  def history(ticket)
    lines = ticket.ticket_activities.sort_by { |activity| [activity.created_at, activity.id] }.map do |activity|
      detalhe = [activity.previous_value, activity.new_value].compact_blank.join(' -> ')
      "[#{time(activity.created_at)}] #{activity.activity_type}#{" (#{activity.user.name})" if activity.user}#{": #{detalhe}" if detalhe.present?}"
    end
    lines.join("\n").presence
  end

  SLA_LABELS = { 'active' => 'Em andamento', 'hit' => 'Cumprido', 'missed' => 'Estourado' }.freeze

  def sla_status(ticket, kind)
    clock = sla_clock(ticket, kind)
    SLA_LABELS[clock.status] if clock
  end

  def sla_due(ticket, kind)
    time(sla_clock(ticket, kind)&.due_at)
  end

  private

  def sla_clock(ticket, kind)
    ticket.current_slas.find { |clock| clock.kind == kind }
  end

  def timezone
    @timezone ||= @account.reporting_timezone.presence || 'UTC'
  end

  def clip(value)
    return value unless value.is_a?(String) && value.length > CELL_LIMIT

    "#{value[0, CELL_LIMIT]}… [texto cortado: limite da célula do Excel]"
  end
end
