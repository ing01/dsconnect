class Ticket < ApplicationRecord
  include Events::Types
  include TicketBroadcastable
  include TicketClosing
  include TicketBlocking
  include TicketFinalizable
  include TicketAssigneeLevels
  include TicketCustomer
  include TicketOpening
  include TicketRelatable
  include TicketCategoryAttachments
  include TicketTriage
  include TicketSlaExtendable

  belongs_to :account
  belongs_to :ticket_column
  belongs_to :assignee, class_name: 'User', optional: true
  # Os responsaveis do Nivel 2 ao teto. `assignee` continua sendo o Nivel 1 -
  # vide AssigneeLeveled. Declarados em laco porque a quantidade que cada Mesa
  # usa e configuracao: o registro tem lugar para todos, e a Mesa diz quais valem.
  (AssigneeLeveled::MIN_LEVEL..AssigneeLeveled::MAX_LEVEL).each do |level|
    belongs_to AssigneeLeveled.assignee_association(level), class_name: 'User', optional: true
  end
  # The ticket's "Mesa de Servico". Mandatory and always kept consistent
  # with `ticket_column.team_id` (see `team_matches_ticket_column`) - a
  # ticket's Mesa is defined by which Mesa's Estagio it currently sits in.
  belongs_to :team
  belongs_to :project, optional: true
  belongs_to :project_task_template, optional: true
  # A Complexidade. Opcional no registro de proposito: todo ticket que ja existe
  # continua valido sem ela, e a exigencia aparece apenas no fechamento - ver
  # TicketClosing#missing_close_requirements.
  belongs_to :ticket_complexity, optional: true

  has_many :ticket_conversations, dependent: :destroy, inverse_of: :ticket
  has_many :conversations, through: :ticket_conversations
  has_many :ticket_activities, dependent: :destroy
  has_many :ticket_comments, dependent: :destroy
  has_many :ticket_attachments, dependent: :destroy
  has_many :ticket_followers, dependent: :destroy
  has_many :followers, through: :ticket_followers, source: :user
  has_many :calendar_event_tickets, dependent: :destroy
  has_many :calendar_events, through: :calendar_event_tickets
  has_many :ticket_checklist_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :ticket
  has_many :ticket_time_entries, -> { order(worked_on: :desc, id: :desc) }, dependent: :destroy, inverse_of: :ticket

  validates :title, presence: true
  validates :custom_attributes, jsonb_attributes_length: true
  validate :ticket_column_belongs_to_account
  validate :team_matches_ticket_column

  # Sobrescreve o teto generico do ApplicationRecord (255 pra string, 20 mil
  # pra text - anti-DOS) so' pra estes dois campos: planilhas de importacao
  # reais (Movidesk) trazem historico de desenvolvimento e descricoes bem
  # mais longos que isso. Nenhuma das duas colunas tem limite no banco
  # (`t.string "jira_key"` sem `limit:`, `t.text "description"`) - so' a
  # validacao generica barrava.
  validates :jira_key, length: { maximum: ApplicationRecord::MAX_TEXT_COLUMN_LENGTH }
  validates :description, length: { maximum: 100_000 }

  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }
  # Lifecycle status. Intentionally independent from `ticket_column` (which
  # represents the Kanban workflow stage/queue a ticket is currently in) and
  # from the status of any linked Conversation - moving columns, resolving,
  # closing and reopening are all distinct, separately tracked transitions.
  # `cancelled` is a terminal state distinct from `closed`: a closed ticket was
  # dealt with, a cancelled one never will be. `close_reason` further qualifies
  # why a ticket left the open state (e.g. 'merged') without needing a global
  # status per reason.
  enum status: { open: 0, resolved: 1, closed: 2, cancelled: 3 }

  # What the Kanban shows. Everything except `open` is a terminal state: the
  # ticket was dealt with (resolved/closed) or never will be (cancelled), so it
  # leaves the operational board. It is still in the database and still reachable
  # through the "Busca detalhada", which deliberately does NOT apply this scope.
  scope :operational, -> { where(status: :open) }

  # Fila de suporte da triagem automatica: nivel do cliente primeiro (5/4 >
  # 3 > 2 > 1), depois prioridade dentro do nivel (alta > media > baixa),
  # com data de criacao como desempate. Independente do `position`/Kanban
  # manual, que continua existindo a parte - esta e uma visualizacao
  # ordenada adicional, nao substitui o board.
  scope :support_queue_order, lambda {
    joins(:company).order(Arel.sql(
      'companies.client_level DESC, ' \
      "CASE tickets.priority WHEN #{priorities[:urgent]} THEN 0 " \
      "WHEN #{priorities[:high]} THEN 1 WHEN #{priorities[:medium]} THEN 2 ELSE 3 END, " \
      'tickets.created_at ASC'
    ))
  }

  # Set while a composite operation (a transfer) writes several tracked columns
  # at once, so the operation logs one auditable activity instead of four
  # disconnected ones. See `Tickets::TransferService`.
  attr_accessor :skip_change_activities

  # Where the ticket was opened from - 'manual', or the channel of the
  # Conversation it was opened from. Set by the caller before saving, because
  # the conversation is only linked after the ticket exists.
  attr_accessor :origin

  before_validation :set_default_position, on: :create
  # Runs as `before_create` (not `before_validation`) so the Postgres
  # advisory lock it takes is scoped to the same transaction as the INSERT
  # (Rails wraps `save!` in one automatically) - it's held until the row is
  # actually committed, closing the race window a `before_validation` lock
  # would leave between releasing the lock and persisting the row.
  before_create :set_display_id

  after_create_commit :log_created_activity, :dispatch_ticket_created_event
  after_update_commit :log_changes_activity, :dispatch_ticket_updated_event
  # Sem isto o card apagado por outra pessoa fica no quadro de todo mundo ate
  # alguem recarregar a pagina.
  after_destroy_commit :dispatch_ticket_deleted_event

  # Maps a changed attribute (from `saved_changes`) to the TicketActivity
  # type it should log. Status transitions are logged separately by
  # resolve!/close!/reopen! (with a more specific activity type), so
  # `status` is intentionally excluded here.
  TRACKED_ATTRIBUTE_ACTIVITY_TYPES = {
    'title' => :title_changed,
    'company_id' => :company_changed,
    'contact_id' => :contact_changed,
    'ticket_category_id' => :category_changed,
    'ticket_column_id' => :column_changed,
    'priority' => :priority_changed,
    'assignee_id' => :assignee_changed,
    'team_id' => :team_changed
  }.freeze

  # Moves the ticket to another column and/or position, re-indexing the
  # affected column(s) so ticket positions stay contiguous after a
  # Kanban drag-and-drop. This is a workflow-stage change only; it never
  # touches `status`.
  def move_to!(ticket_column:, position:)
    validate_target_column_rules!(ticket_column)
    transaction do
      previous_column = self.ticket_column
      # Keeps `team_id` (Mesa) in lockstep with the Estagio being moved
      # into, so a ticket can never end up pointing at a column from a
      # different Mesa than the one it's tagged with.
      update!(ticket_column: ticket_column, team: ticket_column.team, position: position)
      reindex_column!(previous_column) if previous_column != ticket_column
      reindex_column!(ticket_column)
    end
  end

  def resolve!(user = Current.user)
    return if resolved?

    ensure_checklist_completed!
    update!(status: :resolved, resolved_at: Time.zone.now)
    ticket_activities.create!(account_id: account_id, user: user, activity_type: :resolved)
    advance_project_stage_if_needed!
  end

  # `skip_requirements` is for administrative closes only - grouping a ticket
  # into another is not a finished attendance. See TicketClosing.
  def close!(user = Current.user, skip_requirements: false)
    return if closed?

    ensure_checklist_completed! unless skip_requirements
    ensure_closeable!(skip_requirements: skip_requirements)

    update!(status: :closed, closed_at: Time.zone.now)
    ticket_activities.create!(account_id: account_id, user: user, activity_type: :closed)
    advance_project_stage_if_needed!
  end

  # Um item de checklist OBRIGATORIO pendente bloqueia a conclusao, a menos
  # que ja exista um Apontamento (calendar_event) vinculado ao ticket - o
  # mesmo criterio que TicketColumn#require_appointment? usa para a trava de
  # coluna. Itens nao obrigatorios sao so informativos e nunca bloqueiam.
  def ensure_checklist_completed!
    return if calendar_events.exists?
    return unless ticket_checklist_items.where(completed: false, required: true).exists?

    errors.add(:base, I18n.t('tickets.checklist.pending_items', default: 'Não é possível concluir esta tarefa. Existem itens pendentes no checklist.'))
    raise ActiveRecord::RecordInvalid.new(self)
  end

  def checklist_pending?
    ticket_checklist_items.where(completed: false, required: true).exists? && calendar_events.empty?
  end

  def advance_project_stage_if_needed!
    return if project.blank? || next_project_stage.blank?

    project.advance_stage!(next_project_stage)
  end

  def validate_target_column_rules!(target_column)
    if target_column.require_due_date? && due_date.blank?
      errors.add(:due_date, I18n.t('tickets.column_rules.require_due_date', default: 'Data de vencimento é obrigatória para esta coluna'))
    end
    if target_column.require_scheduled_at? && scheduled_at.blank?
      errors.add(:scheduled_at, I18n.t('tickets.column_rules.require_scheduled_at', default: 'Data de agendamento é obrigatória para esta coluna'))
    end
    if target_column.require_appointment? && calendar_events.empty?
      errors.add(:base, I18n.t('tickets.column_rules.require_appointment', default: 'Apontamento é obrigatório para esta coluna'))
    end
    if target_column.require_assignee? && assignee_id.blank?
      errors.add(:assignee, I18n.t('tickets.column_rules.require_assignee', default: 'Responsável é obrigatório para esta coluna'))
    end

    raise ActiveRecord::RecordInvalid.new(self) if errors.any?
  end

  def reopen!(user = Current.user)
    return if open?

    update!(status: :open, resolved_at: nil, closed_at: nil, cancelled_at: nil, close_reason: nil)
    ticket_activities.create!(account_id: account_id, user: user, activity_type: :reopened)
  end

  # Cancelling never deletes the ticket - it is a terminal status, so the
  # record, its history and its attachments all stay readable.
  def cancel!(user = Current.user, reason: nil)
    return if cancelled?

    transaction do
      update!(status: :cancelled, cancelled_at: Time.zone.now, close_reason: reason.presence || 'cancelled')
      ticket_activities.create!(
        account_id: account_id, user: user, activity_type: :cancelled,
        previous_value: status_previously_was, meta: { reason: reason }.compact
      )
    end
  end

  # Solicitante. A ticket has no contact FK, so the requester is the contact of
  # the earliest linked Conversation. Resolved in Ruby rather than SQL so it
  # reuses the `conversations: :contact` preload instead of firing a query, and
  # `min_by(&:id)` makes it deterministic - `conversations.first` has no ORDER BY.
  # There is no `created_by_id` column; the opener is whoever the `created`
  # activity was attributed to. Nullable - tickets created outside a request
  # (seeds, console, automation) have no acting user.
  def created_by_user
    return @created_by_user if defined?(@created_by_user)

    @created_by_user = ticket_activities.to_a.find { |activity| activity.activity_type == 'created' }&.user
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (ticket_column&.tickets&.maximum(:position) || -1) + 1
  end

  # Human-friendly, per-account sequential ticket number (e.g. #42), kept
  # separate from the internal primary key `id`. Uses a Postgres advisory
  # transaction lock (rather than a DB sequence/trigger like
  # Conversation#display_id) so account creation/teardown doesn't need to
  # manage a per-account sequence object. Must run inside the save
  # transaction (see the `before_create` callback above) so the lock is held
  # until this ticket's row is actually committed.
  def set_display_id
    return if display_id.present? || account_id.blank?

    Ticket.connection.execute("SELECT pg_advisory_xact_lock(#{account_id.to_i}, 891273461)")
    self.display_id = (Ticket.where(account_id: account_id).maximum(:display_id) || 0) + 1
  end

  def reindex_column!(column)
    column.tickets.order(:position, :id).each_with_index do |ticket, index|
      ticket.update_column(:position, index) if ticket.position != index # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def ticket_column_belongs_to_account
    return if ticket_column.blank? || account.blank?

    errors.add(:ticket_column, :invalid) if ticket_column.team.account_id != account_id
  end

  # A ticket's Mesa (`team`) must be the same Mesa its Estagio
  # (`ticket_column`) belongs to - there's no such thing as a ticket sitting
  # in one Mesa's column while being "owned" by a different Mesa.
  def team_matches_ticket_column
    return if ticket_column.blank? || team.blank?

    errors.add(:team, :invalid) if ticket_column.team_id != team_id
  end

  # One entry carrying the ticket's opening state, rather than a separate event
  # per field the form happened to fill in.
  def log_created_activity
    ticket_activities.create!(
      account_id: account_id, user: Current.user, activity_type: :created,
      meta: creation_meta
    )
  end

  def creation_meta
    {
      origin: origin.presence || 'manual',
      company_id: company_id, contact_id: contact_id,
      team_id: team_id, ticket_column_id: ticket_column_id,
      ticket_category_id: ticket_category_id, ticket_category_name: ticket_category&.name,
      priority: priority, assignee_id: assignee_id, parent_id: parent_id
    }.compact
  end

  def log_changes_activity
    return if skip_change_activities

    changes = saved_changes
    TRACKED_ATTRIBUTE_ACTIVITY_TYPES.each do |attribute, activity_type|
      next unless changes.key?(attribute)

      previous_value, new_value = changes[attribute]
      next if previous_value == new_value

      ticket_activities.create!(
        account_id: account_id,
        user: Current.user,
        activity_type: activity_type,
        previous_value: previous_value&.to_s,
        new_value: new_value&.to_s
      )
    end
  end
end
