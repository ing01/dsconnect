class TicketChecklistItem < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :completed_by, class_name: 'User', optional: true

  # `checkbox` is the only type completed by manual toggle (see #toggle!).
  # The others are completed automatically from whatever the agent fills in
  # `value` - a free text answer, a number, or one of `options` - so the
  # checklist can ask for actual information, not just a yes/no.
  ITEM_TYPES = %w[checkbox text single_select number].freeze

  validates :title, presence: true
  validates :item_type, inclusion: { in: ITEM_TYPES }

  before_validation :set_default_position, on: :create
  before_save :sync_completed_from_value, unless: :checkbox?

  # So a conclusao e a reabertura contam: editar o texto ou reordenar nao muda o
  # andamento do ticket.
  after_update_commit :log_completion_activity, if: :saved_change_to_completed?

  scope :ordered, -> { order(:position, :id) }

  def checkbox?
    item_type == 'checkbox'
  end

  def toggle!(user = Current.user)
    if completed?
      update!(completed: false, completed_at: nil, completed_by: nil)
    else
      update!(completed: true, completed_at: Time.zone.now, completed_by: user)
    end
  end

  private

  def log_completion_activity
    ticket.log_activity!(
      completed? ? :checklist_item_completed : :checklist_item_reopened,
      user: completed_by || Current.user, new_value: title,
      details: { 'Item' => title, 'Resposta' => (value.presence unless checkbox?) }.compact
    )
  end

  def sync_completed_from_value
    was_completed = completed?
    self.completed = value.present?

    return if completed == was_completed

    if completed?
      self.completed_at = Time.zone.now
      self.completed_by = Current.user
    else
      self.completed_at = nil
      self.completed_by = nil
    end
  end

  def set_default_position
    return if position.present? && position != 0

    self.position = (ticket&.ticket_checklist_items&.maximum(:position) || -1) + 1
  end
end
