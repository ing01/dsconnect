class TicketColumn < ApplicationRecord
  belongs_to :ticket_board

  has_many :tickets, -> { order(:position) }, dependent: :restrict_with_error, inverse_of: :ticket_column

  validates :name, presence: true

  before_validation :set_default_position, on: :create

  delegate :account, to: :ticket_board

  # Persists a new column order for a board from an ordered array of column ids.
  def self.reorder!(ticket_board, column_ids)
    transaction do
      column_ids.each_with_index do |id, index|
        ticket_board.ticket_columns.where(id: id).update_all(position: index) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def push_event_data
    {
      id: id,
      name: name,
      position: position
    }
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (ticket_board&.ticket_columns&.maximum(:position) || -1) + 1
  end
end
