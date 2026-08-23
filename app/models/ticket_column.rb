class TicketColumn < ApplicationRecord
  belongs_to :team

  has_many :tickets, -> { order(:position) }, dependent: :restrict_with_error, inverse_of: :ticket_column

  validates :name, presence: true

  before_validation :set_default_position, on: :create

  delegate :account, to: :team

  # Persists a new column order for a team's Kanban ("Mesa de Servico") from
  # an ordered array of column ids.
  def self.reorder!(team, column_ids)
    transaction do
      column_ids.each_with_index do |id, index|
        team.ticket_columns.where(id: id).update_all(position: index) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def push_event_data
    {
      id: id,
      name: name,
      position: position,
      team_id: team_id
    }
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (team&.ticket_columns&.maximum(:position) || -1) + 1
  end
end
