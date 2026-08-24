class TicketColumn < ApplicationRecord
  belongs_to :team

  has_many :tickets, -> { order(:position, :id) }, dependent: :restrict_with_error, inverse_of: :ticket_column

  validates :name, presence: true
  validate :team_change_requires_empty_column, on: :update

  before_validation :set_default_position, on: :create
  before_save :reset_position_for_new_team, if: -> { persisted? && team_id_changed? }
  # Runs ahead of the callback `dependent: :restrict_with_error` installs, so the
  # API answers with a message that says how many tickets are in the way and what
  # to do about them instead of Rails' generic wording.
  before_destroy :ensure_no_tickets, prepend: true

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

  def ensure_no_tickets
    ticket_count = tickets.count
    return if ticket_count.zero?

    errors.add(:base, I18n.t('errors.ticket_column.has_tickets', count: ticket_count))
    throw :abort
  end

  # An Estagio can only be handed to another Mesa while it is empty: a ticket must
  # always sit in a column belonging to its own Mesa (Ticket#team_matches_ticket_column),
  # so moving a populated column would invalidate every ticket in it.
  def team_change_requires_empty_column
    return unless team_id_changed?

    ticket_count = tickets.count
    return if ticket_count.zero?

    errors.add(:base, I18n.t('errors.ticket_column.team_change_with_tickets', count: ticket_count))
  end

  def reset_position_for_new_team
    self.position = (TicketColumn.where(team_id: team_id).where.not(id: id).maximum(:position) || -1) + 1
  end
end
