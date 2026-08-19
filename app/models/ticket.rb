class Ticket < ApplicationRecord
  belongs_to :account
  belongs_to :ticket_column
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :team, optional: true

  has_many :ticket_conversations, dependent: :destroy, inverse_of: :ticket
  has_many :conversations, through: :ticket_conversations

  validates :title, presence: true
  validates :custom_attributes, jsonb_attributes_length: true
  validate :ticket_column_belongs_to_account

  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }

  before_validation :set_default_position, on: :create

  # Moves the ticket to another column and/or position, re-indexing the
  # affected column(s) so ticket positions stay contiguous after a
  # Kanban drag-and-drop.
  def move_to!(ticket_column:, position:)
    transaction do
      previous_column = self.ticket_column
      update!(ticket_column: ticket_column, position: position)
      reindex_column!(previous_column) if previous_column != ticket_column
      reindex_column!(ticket_column)
    end
  end

  def push_event_data
    {
      id: id,
      title: title,
      description: description,
      priority: priority,
      position: position,
      ticket_column_id: ticket_column_id,
      assignee_id: assignee_id,
      team_id: team_id,
      conversation_ids: ticket_conversations.pluck(:conversation_id)
    }
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (ticket_column&.tickets&.maximum(:position) || -1) + 1
  end

  def reindex_column!(column)
    column.tickets.order(:position, :id).each_with_index do |ticket, index|
      ticket.update_column(:position, index) if ticket.position != index # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def ticket_column_belongs_to_account
    return if ticket_column.blank? || account.blank?

    errors.add(:ticket_column, :invalid) if ticket_column.ticket_board.account_id != account_id
  end
end
