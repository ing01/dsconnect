class TicketComment < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :user

  validates :content, presence: true

  # Ticket finalizado nao recebe mais nada: e registro historico. A checagem e
  # `on: :create` porque o que se impede e acrescentar depois do fim - o que ja
  # existia continua la, e continua legivel.
  validate :ticket_not_finalized, on: :create

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

  def ticket_not_finalized
    return unless ticket&.finalized?

    errors.add(:base, I18n.t('tickets.finalized.immutable'))
  end

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
