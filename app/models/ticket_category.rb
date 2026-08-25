# A ticket's category ("Duvida", "Erro", "Homologacao"...), scoped to a Mesa.
# Same shape as TicketColumn: the Mesa owns the list, and two Mesas can have
# completely different ones.
class TicketCategory < ApplicationRecord
  belongs_to :team

  has_many :tickets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :team_id }

  before_validation :set_default_position, on: :create

  delegate :account, to: :team

  scope :ordered, -> { order(:position, :id) }

  def push_event_data
    { id: id, name: name, position: position, team_id: team_id }
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (team&.ticket_categories&.maximum(:position) || -1) + 1
  end
end
