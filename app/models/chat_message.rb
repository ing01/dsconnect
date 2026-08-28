# Uma mensagem do Chat Interno.
class ChatMessage < ApplicationRecord
  include Events::Types

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
  after_create_commit :touch_channel, :dispatch_created_event

  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  # O mesmo formato que a API devolve, para que a mensagem que chega pelo tempo
  # real e a que vem por HTTP sejam indistinguiveis na tela.
  def push_event_data
    {
      id: id,
      userId: user_id,
      body: content,
      createdAt: created_at.to_i,
      replyTo: reply_to_id,
      reactions: reactions_payload.map { |item| { emoji: item[:emoji], userIds: item[:user_ids] } }
    }
  end

  # Avisa quem participa da sala. Chamado tambem quando uma reacao muda, porque
  # a tela substitui a mensagem inteira.
  def dispatch_updated_event
    dispatch_event(INTERNAL_CHAT_MESSAGE_UPDATED)
  end

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

  def dispatch_created_event
    dispatch_event(INTERNAL_CHAT_MESSAGE_CREATED)
  end

  def dispatch_event(name)
    Rails.configuration.dispatcher.dispatch(name, Time.zone.now, chat_message: self)
  end
end
