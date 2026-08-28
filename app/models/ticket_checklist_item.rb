class TicketChecklistItem < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :completed_by, class_name: 'User', optional: true

  validates :title, presence: true

  before_validation :set_default_position, on: :create

  scope :ordered, -> { order(:position, :id) }

  def toggle!(user = Current.user)
    if completed?
      update!(completed: false, completed_at: nil, completed_by: nil)
    else
      update!(completed: true, completed_at: Time.zone.now, completed_by: user)
    end
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (ticket&.ticket_checklist_items&.maximum(:position) || -1) + 1
  end
end
