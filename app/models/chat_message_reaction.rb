# A reacao de uma pessoa a uma mensagem. Uma linha por pessoa e emoji, entao a
# contagem e sempre uma consulta e nunca um contador que possa dessincronizar.
class ChatMessageReaction < ApplicationRecord
  belongs_to :account
  belongs_to :chat_message
  belongs_to :user

  validates :emoji, presence: true
  validates :user_id, uniqueness: { scope: %i[chat_message_id emoji] }

  before_validation :ensure_account_id

  private

  def ensure_account_id
    self.account_id ||= chat_message&.account_id
  end
end
