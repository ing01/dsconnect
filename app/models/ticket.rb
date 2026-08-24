class Ticket < ApplicationRecord
  include Events::Types

  belongs_to :account
  belongs_to :ticket_column
  belongs_to :assignee, class_name: 'User', optional: true
  # The ticket's "Mesa de Servico". Mandatory and always kept consistent
  # with `ticket_column.team_id` (see `team_matches_ticket_column`) - a
  # ticket's Mesa is defined by which Mesa's Estagio it currently sits in.
  belongs_to :team

  has_many :ticket_conversations, dependent: :destroy, inverse_of: :ticket
  has_many :conversations, through: :ticket_conversations
  has_many :ticket_activities, dependent: :destroy
  has_many :ticket_comments, dependent: :destroy
  has_many :calendar_event_tickets, dependent: :destroy
  has_many :calendar_events, through: :calendar_event_tickets

  validates :title, presence: true
  validates :custom_attributes, jsonb_attributes_length: true
  validate :ticket_column_belongs_to_account
  validate :team_matches_ticket_column

  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }
  # Lifecycle status. Intentionally independent from `ticket_column` (which
  # represents the Kanban workflow stage/queue a ticket is currently in) and
  # from the status of any linked Conversation - moving columns, resolving,
  # closing and reopening are all distinct, separately tracked transitions.
  enum status: { open: 0, resolved: 1, closed: 2 }

  before_validation :set_default_position, on: :create
  # Runs as `before_create` (not `before_validation`) so the Postgres
  # advisory lock it takes is scoped to the same transaction as the INSERT
  # (Rails wraps `save!` in one automatically) - it's held until the row is
  # actually committed, closing the race window a `before_validation` lock
  # would leave between releasing the lock and persisting the row.
  before_create :set_display_id

  after_create_commit :log_created_activity, :dispatch_ticket_created_event
  after_update_commit :log_changes_activity, :dispatch_ticket_updated_event

  # Maps a changed attribute (from `saved_changes`) to the TicketActivity
  # type it should log. Status transitions are logged separately by
  # resolve!/close!/reopen! (with a more specific activity type), so
  # `status` is intentionally excluded here.
  TRACKED_ATTRIBUTE_ACTIVITY_TYPES = {
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

    update!(status: :resolved, resolved_at: Time.zone.now)
    ticket_activities.create!(account_id: account_id, user: user, activity_type: :resolved)
  end

  def close!(user = Current.user)
    return if closed?

    update!(status: :closed, closed_at: Time.zone.now)
    ticket_activities.create!(account_id: account_id, user: user, activity_type: :closed)
  end

  def reopen!(user = Current.user)
    return if open?

    update!(status: :open, resolved_at: nil, closed_at: nil)
    ticket_activities.create!(account_id: account_id, user: user, activity_type: :reopened)
  end

  def push_event_data
    {
      id: id,
      display_id: display_id,
      title: title,
      description: description,
      priority: priority,
      status: status,
      position: position,
      account_id: account_id,
      ticket_column_id: ticket_column_id,
      assignee_id: assignee_id,
      team_id: team_id,
      resolved_at: resolved_at&.to_i,
      closed_at: closed_at&.to_i,
      created_at: created_at.to_i,
      updated_at: updated_at.to_i,
      conversation_ids: ticket_conversations.pluck(:conversation_id)
    }
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

  def log_created_activity
    ticket_activities.create!(account_id: account_id, user: Current.user, activity_type: :created)
  end

  def log_changes_activity
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

  def dispatch_ticket_created_event
    dispatcher_dispatch(TICKET_CREATED)
  end

  def dispatch_ticket_updated_event
    dispatcher_dispatch(ticket_update_event_name)
  end

  def ticket_update_event_name
    return TICKET_MOVED if saved_change_to_attribute?('ticket_column_id')
    return status_event_name if saved_change_to_attribute?('status')

    TICKET_UPDATED
  end

  def status_event_name
    case status
    when 'resolved' then TICKET_RESOLVED
    when 'closed' then TICKET_CLOSED
    else TICKET_REOPENED
    end
  end

  def dispatcher_dispatch(event_name)
    Rails.configuration.dispatcher.dispatch(event_name, Time.zone.now, ticket: self)
  end
end
