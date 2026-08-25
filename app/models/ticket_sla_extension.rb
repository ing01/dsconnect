# One manual extension of a ticket's deadline. Kept as its own row (rather than
# only mutating `tickets.due_at`) so every hour granted stays attributable and
# reversible in the audit trail.
class TicketSlaExtension < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  # Nullable so removing an agent never erases the extension they granted.
  belongs_to :user, optional: true

  MAXIMUM_HOURS = 999

  validates :reason, presence: true
  validates :hours, numericality: { greater_than: 0, less_than_or_equal_to: MAXIMUM_HOURS }

  before_validation :ensure_account_id

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end
end
