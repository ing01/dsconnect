# A user watching a ticket. Distinct from `assignee`, which is the single
# person responsible - followers only receive visibility.
class TicketFollower < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :user

  validates :user_id, uniqueness: { scope: :ticket_id }

  before_validation :ensure_account_id

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end
end
