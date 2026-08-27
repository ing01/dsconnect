# Uma mensagem do Chat Interno.
class ChatMessage < ApplicationRecord
  belongs_to :account
  belongs_to :chat_channel
  # Nulo quando o agente e removido: a conversa nao perde o historico.
  belongs_to :user, optional: true
  belongs_to :reply_to, class_name: 'ChatMessage', optional: true

  has_many :chat_message_reactions, dependent: :destroy

  validates :content, presence: true

  before_validation :ensure_account_id
  # A sala guarda a data da ultima mensagem para poder ser ordenada sem varrer
  # a tabela de mensagens.
  after_create_commit :touch_channel

  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  # As reacoes agrupadas por emoji, no formato que a tela desenha.
  def reactions_payload
    chat_message_reactions.group_by(&:emoji).map do |emoji, reactions|
      { emoji: emoji, user_ids: reactions.map(&:user_id) }
    end
  end

  private

  def ensure_account_id
    self.account_id ||= chat_channel&.account_id
  end

  def touch_channel
    chat_channel.update_column(:last_message_at, created_at) # rubocop:disable Rails/SkipsModelValidations
  end
end
