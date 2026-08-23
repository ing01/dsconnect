class TicketComment < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :user

  validates :content, presence: true

  before_validation :ensure_account_id

  after_create_commit :log_comment_activity

  def push_event_data
    {
      id: id,
      ticket_id: ticket_id,
      content: content,
      user: { id: user.id, name: user.name },
      created_at: created_at.to_i
    }
  end

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end

  def log_comment_activity
    ticket.ticket_activities.create!(
      account_id: account_id,
      user: user,
      activity_type: :comment_added,
      meta: { ticket_comment_id: id }
    )
  end
end
