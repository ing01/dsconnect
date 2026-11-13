# O que cada acao do painel em lote faz num ticket. Reaproveita o codigo de
# dominio das acoes individuais (resolve!/close!/cancel!/TransferService/...),
# entao as regras de cada uma valem aqui do mesmo jeito.
#
# `apply` devolve o estado anterior (usado pelo desfazer) ou levanta `Skip`
# quando o ticket nao precisa ou nao pode ser alterado por um motivo esperado.
module Tickets::BulkOperations::Handlers
  class Skip < StandardError
    attr_reader :code

    def initialize(code, message = nil)
      @code = code
      super(message || code)
    end
  end

  FIELD_ACTIONS = %w[priority due_date scheduled_at category complexity contact_company].freeze
  REVERSIBLE = (FIELD_ACTIONS + %w[assignee stage team]).freeze
  ACTIONS = (REVERSIBLE + %w[followers comment customer_message resolve close cancel reopen]).freeze

  module_function

  def apply(action, ticket, user, params)
    case action
    when *FIELD_ACTIONS then apply_fields(action, ticket, params)
    when 'assignee' then apply_assignee(ticket, params)
    when 'stage' then apply_stage(ticket, params)
    when 'team' then apply_team(ticket, user, params)
    when 'followers' then apply_followers(ticket, params)
    when 'comment' then apply_comment(ticket, user, params)
    when 'resolve' then apply_status(ticket) { ticket.resolve!(user) }
    when 'reopen' then apply_status(ticket) { ticket.reopen!(user) }
    when 'close' then apply_close(ticket, user, params)
    when 'cancel' then apply_cancel(ticket, user, params)
    end
  end

  def skip!(code)
    raise Skip.new(code, I18n.t("tickets.bulk.reasons.#{code}"))
  end

  # Desfaz um item: so mexe no ticket se ele ainda esta como a operacao deixou.
  def undo(action, ticket, snapshot)
    after = snapshot['after'] || {}
    current = ticket.reload.slice(*after.keys).transform_values { |value| normalize(value) }
    skip!('changed_since') if current != after.transform_values { |value| normalize(value) }

    ticket.as_administrative_change { restore(action, ticket, snapshot['before']) }
  end

  def restore(action, ticket, before)
    if %w[stage team].include?(action)
      column = ticket.account.ticket_columns.find(before['ticket_column_id'])
      position = Tickets::ColumnPosition.new(ticket: ticket, column: column).by_display_id
      ticket.move_to!(ticket_column: column, position: position)
      ticket.update!(before.except('ticket_column_id', 'team_id'))
    else
      ticket.update!(before)
    end
  end

  def normalize(value)
    value.respond_to?(:iso8601) ? value.iso8601 : value
  end

  def apply_fields(action, ticket, params)
    attrs = field_attributes(action, ticket, params)
    keys = attrs.keys.map(&:to_s)
    before = ticket.slice(*keys).transform_values { |value| normalize(value) }
    skip!('unchanged') if attrs.blank?

    ticket.assign_attributes(attrs)
    skip!('unchanged') unless ticket.changed?

    # So' categoria tem licenca de mexer em ticket ja fechado/cancelado -
    # TicketFinalizable bloquearia o save normal (`unchanged_once_finalized`).
    # As outras acoes de campo continuam batendo nessa trava normalmente.
    if action == 'category' && ticket.finalized?
      ticket.as_administrative_change { ticket.save! }
    else
      ticket.save!
    end
    { 'before' => before, 'after' => ticket.reload.slice(*keys).transform_values { |value| normalize(value) } }
  end

  def field_attributes(action, ticket, params)
    case action
    when 'priority' then { priority: params['priority'] }
    when 'due_date' then { due_date: params['due_date'].presence }
    when 'scheduled_at' then { scheduled_at: params['scheduled_at'].presence }
    when 'category' then { ticket_category_id: valid_category(ticket, params['ticket_category_id']) }
    when 'complexity' then { ticket_complexity_id: params['ticket_complexity_id'].presence }
    else contact_company_attributes(params)
    end
  end

  def valid_category(ticket, id)
    return nil if id.blank?

    category = TicketCategory.find_by(id: id)
    return category.id if category && category.team_id == ticket.team_id

    skip!('category_other_team')
  end

  def contact_company_attributes(params)
    attrs = {}
    attrs[:contact_id] = params['contact_id'].presence if params.key?('contact_id')
    attrs[:company_id] = params['company_id'].presence if params.key?('company_id')
    attrs
  end

  def apply_assignee(ticket, params)
    level = params['level'].presence || AssigneeLeveled::FIRST_LEVEL
    skip!('invalid_level') unless AssigneeLeveled.valid_level?(level)

    column = AssigneeLeveled.assignee_column(level)
    new_id = params['user_id'].presence&.to_i
    skip!('not_team_member') if new_id && ticket.team && !ticket.team.members.exists?(id: new_id)
    skip!('unchanged') if ticket[column] == new_id

    before = { column.to_s => ticket[column] }
    ticket.update!(column => new_id)
    { 'before' => before, 'after' => { column.to_s => ticket.reload[column] } }
  end

  def apply_stage(ticket, params)
    column = ticket.account.ticket_columns.find_by(id: params['ticket_column_id'])
    skip!('column_not_found') if column.nil?
    skip!('stage_other_team') if column.team_id != ticket.team_id
    skip!('unchanged') if column.id == ticket.ticket_column_id

    before = { 'ticket_column_id' => ticket.ticket_column_id }
    position = Tickets::ColumnPosition.new(ticket: ticket, column: column).by_display_id
    ticket.move_to!(ticket_column: column, position: position)
    { 'before' => before, 'after' => { 'ticket_column_id' => column.id } }
  end

  # Muda a Mesa e limpa o(s) responsavel(is) que nao fazem parte da nova.
  def apply_team(ticket, user, params)
    team = ticket.account.teams.find_by(id: params['team_id'])
    skip!('team_not_found') if team.nil?
    skip!('unchanged') if team.id == ticket.team_id

    column = (params['ticket_column_id'].present? && team.ticket_columns.find_by(id: params['ticket_column_id'])) ||
             team.ticket_columns.first
    skip!('team_without_stage') if column.nil?

    keys = %w[team_id ticket_column_id ticket_category_id] + AssigneeLeveled::ALL_LEVELS.map { |l| AssigneeLeveled.assignee_column(l).to_s }
    before = ticket.slice(*keys)
    member_ids = team.members.pluck(:id)
    keep_assignee = member_ids.include?(ticket.assignee_id) ? ticket.assignee_id : nil
    Tickets::TransferService.new(
      ticket: ticket, user: user, attributes: { ticket_column_id: column.id, assignee_id: keep_assignee }
    ).perform
    clear_foreign_fields(ticket, team, member_ids)
    { 'before' => before, 'after' => ticket.reload.slice(*keys) }
  end

  def clear_foreign_fields(ticket, team, member_ids)
    updates = {}
    ((AssigneeLeveled::FIRST_LEVEL + 1)..AssigneeLeveled::MAX_LEVEL).each do |level|
      column = AssigneeLeveled.assignee_column(level)
      updates[column] = nil if ticket[column] && member_ids.exclude?(ticket[column])
    end
    updates[:ticket_category_id] = nil if ticket.ticket_category && ticket.ticket_category.team_id != team.id
    ticket.update!(updates) if updates.any?
  end

  def apply_followers(ticket, params)
    ids = Array(params['user_ids']).map(&:to_i) - ticket.ticket_followers.pluck(:user_id)
    skip!('unchanged') if ids.empty?

    ids.each { |id| ticket.ticket_followers.create!(user_id: id) }
    nil
  end

  def apply_comment(ticket, user, params)
    ticket.ticket_comments.create!(user: user, content: params['body'])
    nil
  end

  def apply_status(ticket)
    status = ticket.status
    yield
    skip!('unchanged') if ticket.status == status
    nil
  end

  # Resolucao, Categoria e Catalogo preenchidos no painel valem para TODOS os
  # tickets - mas so onde o ticket ainda nao tem o seu proprio valor.
  def apply_close(ticket, user, params)
    skip!('unchanged') if ticket.closed?

    fill_close_fields(ticket, user, params)
    ticket.close!(user, resolution: ticket.resolution.presence || params['resolution'])
    nil
  rescue TicketClosing::NotAllowed => e
    raise Skip.new('close_requirements_missing', I18n.t('tickets.bulk.reasons.close_missing', missing: e.missing.join(', ')))
  end

  def fill_close_fields(ticket, user, params)
    if ticket.ticket_category_id.blank? && params['ticket_category_id'].present?
      ticket.update!(ticket_category_id: valid_category(ticket, params['ticket_category_id']))
    end
    return if ticket.classified? || params['service_catalog_item_id'].blank?

    item = ServiceCatalogItem.joins(service_catalog_area: :service_catalog)
                             .find_by(id: params['service_catalog_item_id'], service_catalogs: { account_id: ticket.account_id })
    ticket.classify!(item, user) if item
  end

  def apply_cancel(ticket, user, params)
    skip!('reason_required') if params['reason'].to_s.strip.blank?

    ticket.cancel!(user, reason: params['reason'].to_s.strip)
    nil
  end
end
