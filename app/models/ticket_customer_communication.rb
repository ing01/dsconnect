# A message sent TO the customer about a ticket, kept apart from TicketComment,
# which is the team's internal thread and never leaves the account.
#
# `status` reflects what the delivery actually did, not what the agent clicked:
# the record is created as `pending`, and only the send path marks it `sent`.
class TicketCustomerCommunication < ApplicationRecord
  belongs_to :account
  # Nullable so removing an agent never erases what was sent to a customer.
  belongs_to :user, optional: true
  belongs_to :ticket
  belongs_to :contact, optional: true

  STATUSES = %w[pending sent failed].freeze

  validates :to_email, :subject, :body, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :to_email_looks_deliverable

  before_validation :ensure_account_id

  scope :sent, -> { where(status: 'sent') }
  # What satisfies the closing requirement: a closing message that actually went
  # out. A pending or failed one does not count.
  scope :closing_sent, -> { sent.where(closing: true) }

  def mark_sent!
    update!(status: 'sent', sent_at: Time.zone.now, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: 'failed', error_message: message.to_s.truncate(1000))
  end

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end

  # Cheap shape check only. Whether the address exists is something only the
  # delivery attempt can answer, and that is what sets the status.
  def to_email_looks_deliverable
    return if to_email.blank?

    errors.add(:to_email, :invalid) unless to_email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
