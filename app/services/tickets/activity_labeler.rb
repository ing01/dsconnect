# Traduz o que uma TicketActivity guardou em texto que uma pessoa le no Historico.
#
# A atividade grava o que mudou do jeito mais barato e estavel: o id de quem era
# o responsavel, o nome interno da prioridade, o numero do ticket pai. Para a
# auditoria isso e pouco - "4 -> 7" nao diz quem passou o ticket para quem. Este
# servico resolve tudo na LEITURA, em lote (uma consulta por tipo de registro,
# nao uma por linha), e por isso tambem corrige as atividades que ja existiam.
#
# O valor bruto continua no payload: o rotulo e acrescentado, nunca substitui. Se
# o registro foi apagado depois, cai no valor gravado em vez de sumir.
class Tickets::ActivityLabeler
  PRIORITY_LABELS = { 'low' => 'Baixa', 'medium' => 'Média', 'high' => 'Alta', 'urgent' => 'Urgente' }.freeze
  STATUS_LABELS = { 'open' => 'Aberto', 'resolved' => 'Resolvido', 'closed' => 'Fechado', 'cancelled' => 'Cancelado' }.freeze
  ORIGIN_LABELS = { 'manual' => 'Manual' }.freeze

  # Qual registro cada tipo de atividade referencia em previous/new_value.
  VALUE_KINDS = {
    'assignee_changed' => :user, 'assignee_level_changed' => :user,
    'team_changed' => :team, 'column_changed' => :column,
    'company_changed' => :company, 'contact_changed' => :contact,
    'category_changed' => :category, 'complexity_changed' => :complexity,
    'priority_changed' => :priority, 'status_changed' => :status, 'cancelled' => :status,
    'transferred' => :team,
    'parent_changed' => :ticket_number, 'merged_ticket' => :ticket_number,
    'merged_into' => :ticket_number, 'child_created' => :ticket_number,
    'duplicated' => :ticket_number,
    'due_date_changed' => :datetime, 'scheduled_at_changed' => :datetime,
    'sla_hours_added' => :datetime
  }.freeze

  # Chave de `meta.changes` (Transferencia) e de `meta` (Criacao) -> tipo do valor.
  FIELD_KINDS = {
    'team_id' => :team, 'ticket_column_id' => :column, 'status' => :status,
    'priority' => :priority, 'assignee_id' => :user, 'company_id' => :company,
    'contact_id' => :contact, 'ticket_category_id' => :category, 'parent_id' => :ticket_id
  }.freeze

  FIELD_NAMES = {
    'team_id' => 'Mesa', 'ticket_column_id' => 'Estágio', 'status' => 'Status',
    'priority' => 'Prioridade', 'assignee_id' => 'Responsável', 'company_id' => 'Empresa',
    'contact_id' => 'Solicitante', 'ticket_category_id' => 'Categoria', 'parent_id' => 'Ticket pai'
  }.freeze

  def initialize(activities)
    @activities = Array(activities)
    @records = {}
    preload
  end

  # => { previous_label:, new_label:, details: [{ label:, previous:, new: }] }
  def labels_for(activity)
    kind = VALUE_KINDS[activity.activity_type]
    {
      previous_label: kind ? format_value(kind, activity.previous_value) : nil,
      new_label: kind ? format_value(kind, activity.new_value) : nil,
      details: details_for(activity)
    }
  end

  private

  # ---- carga em lote ------------------------------------------------------

  def model_for(kind)
    {
      user: User, team: Team, column: TicketColumn, category: TicketCategory,
      complexity: TicketComplexity, contact: Contact, company: Ticket.reflect_on_association(:company).klass,
      ticket_id: Ticket
    }[kind]
  end

  def preload
    wanted = Hash.new { |hash, key| hash[key] = Set.new }
    @activities.each { |activity| collect_ids(activity, wanted) }
    wanted.each do |kind, ids|
      klass = model_for(kind)
      @records[kind] = klass ? klass.where(id: ids.to_a).index_by(&:id) : {}
    end
  end

  def collect_ids(activity, wanted)
    kind = VALUE_KINDS[activity.activity_type]
    if kind && model_for(kind)
      [activity.previous_value, activity.new_value].each { |value| wanted[kind] << value.to_i if value.present? }
    end
    each_meta_pair(activity) do |field, from, to|
      field_kind = FIELD_KINDS[field]
      next unless field_kind && model_for(field_kind)

      [from, to].each { |value| wanted[field_kind] << value.to_i if value.present? }
    end
    meta_user = activity.meta.to_h['user_id']
    wanted[:user] << meta_user.to_i if meta_user.present?
  end

  # Percorre os pares antes/depois de uma Transferencia (`meta.changes`) e os
  # valores de abertura de uma Criacao (`meta`), no mesmo formato.
  def each_meta_pair(activity)
    meta = activity.meta.to_h
    if activity.activity_type == 'transferred'
      meta['changes'].to_h.each { |field, (from, to)| yield(field, from, to) }
    elsif activity.activity_type == 'created'
      FIELD_KINDS.each_key { |field| yield(field, nil, meta[field]) if meta[field].present? }
    end
  end

  # ---- formatacao ---------------------------------------------------------

  def format_value(kind, value)
    return nil if value.blank?

    case kind
    when :priority then PRIORITY_LABELS[value.to_s] || value.to_s
    when :status then STATUS_LABELS[value.to_s] || value.to_s
    when :datetime then format_time(value)
    when :ticket_number then "##{value}"
    when :ticket_id then ticket_label(value)
    else
      record_label(kind, value) || value.to_s
    end
  end

  def record_label(kind, value)
    record = @records.dig(kind, value.to_i)
    return unless record

    kind == :column ? record.name : record.try(:name) || record.to_s
  end


  def ticket_label(value)
    ticket = @records.dig(:ticket_id, value.to_i)
    ticket ? "##{ticket.display_id} - #{ticket.title}" : "##{value}"
  end

  def format_time(value)
    Time.zone.parse(value.to_s)&.strftime('%d/%m/%Y %H:%M') || value.to_s
  rescue ArgumentError
    value.to_s
  end

  # ---- detalhes -----------------------------------------------------------

  def details_for(activity)
    case activity.activity_type
    when 'transferred' then transfer_details(activity)
    when 'created' then creation_details(activity)
    when 'sla_hours_added' then sla_details(activity)
    when 'customer_communication_sent' then communication_details(activity)
    when 'cancelled' then reason_details(activity)
    when 'assignee_level_changed' then level_details(activity)
    when 'attachment_added', 'attachment_removed', 'time_entry_added', 'time_entry_removed',
         'checklist_item_completed', 'checklist_item_reopened', 'conversation_linked',
         'conversation_unlinked'
      meta_details(activity)
    else []
    end
  end

  def transfer_details(activity)
    activity.meta.to_h['changes'].to_h.map do |field, (from, to)|
      kind = FIELD_KINDS[field]
      { label: FIELD_NAMES[field] || field, previous: format_value(kind, from), new: format_value(kind, to) }
    end
  end

  def creation_details(activity)
    meta = activity.meta.to_h
    rows = [{ label: 'Origem', previous: nil, new: origin_label(meta['origin']) }]
    FIELD_KINDS.each do |field, kind|
      value = meta[field]
      next if value.blank?

      rows << { label: FIELD_NAMES[field], previous: nil, new: format_value(kind, value) }
    end
    rows
  end

  def origin_label(origin)
    ORIGIN_LABELS[origin.to_s] || origin.to_s.presence
  end

  def sla_details(activity)
    meta = activity.meta.to_h
    rows = [{ label: 'Prazo', previous: format_value(:datetime, activity.previous_value), new: format_value(:datetime, activity.new_value) }]
    rows << { label: 'Tipo de SLA', previous: nil, new: meta['sla_kind'] } if meta['sla_kind'].present?
    rows << { label: 'Horas adicionadas', previous: nil, new: meta['hours'].to_s } if meta['hours'].present?
    rows << { label: 'Motivo', previous: nil, new: meta['reason'] } if meta['reason'].present?
    rows
  end

  def communication_details(activity)
    meta = activity.meta.to_h
    rows = []
    rows << { label: 'Assunto', previous: nil, new: meta['subject'] } if meta['subject'].present?
    rows << { label: 'Enviado por e-mail', previous: nil, new: meta['notify_customer'] == false ? 'Não' : 'Sim' }
    rows << { label: 'Mensagem de encerramento', previous: nil, new: 'Sim' } if meta['closing']
    rows
  end

  def reason_details(activity)
    rows = [{ label: 'Status', previous: format_value(:status, activity.previous_value), new: STATUS_LABELS['cancelled'] }]
    reason = activity.meta.to_h['reason']
    rows << { label: 'Motivo', previous: nil, new: reason } if reason.present?
    rows
  end

  def level_details(activity)
    level = activity.meta.to_h['level']
    level.present? ? [{ label: 'Nível', previous: nil, new: level.to_s }] : []
  end

  # Atividades que descrevem o proprio fato em `meta.details` ({ rotulo => valor }),
  # gravado por quem as registra - assim o Historico mostra o arquivo, o
  # apontamento ou o item sem precisar conhecer cada modelo.
  def meta_details(activity)
    activity.meta.to_h['details'].to_h.map { |label, value| { label: label, previous: nil, new: value.to_s } }
  end
end
