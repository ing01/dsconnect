class TicketConversation < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :conversation

  validates :ticket_id, uniqueness: { scope: :conversation_id }
  validate :conversation_belongs_to_same_account

  before_validation :ensure_account_id

  after_create_commit :dispatch_conversation_updated_event
  after_destroy_commit :dispatch_conversation_updated_event

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end

  def conversation_belongs_to_same_account
    return if ticket.blank? || conversation.blank?

    errors.add(:conversation, :invalid) if conversation.account_id != ticket.account_id
  end

  def dispatch_conversation_updated_event
    conversation.dispatch_conversation_updated_event
  end
end
