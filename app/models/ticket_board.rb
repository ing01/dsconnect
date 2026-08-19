class TicketBoard < ApplicationRecord
  belongs_to :account

  has_many :ticket_columns, -> { order(:position) }, dependent: :destroy, inverse_of: :ticket_board
  has_many :tickets, through: :ticket_columns

  validates :name, presence: true

  def push_event_data
    {
      id: id,
      name: name,
      ticket_columns: ticket_columns.map(&:push_event_data)
    }
  end
end
