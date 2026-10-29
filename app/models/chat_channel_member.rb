# A participacao de alguem numa sala, com o ponto ate onde essa pessoa leu.
class ChatChannelMember < ApplicationRecord
  belongs_to :account
  belongs_to :chat_channel
  belongs_to :user

  validates :user_id, uniqueness: { scope: :chat_channel_id }

  before_validation :ensure_account_id

  # Marca tudo como lido ate agora.
  def mark_read!
    update!(last_read_at: Time.zone.now)
  end

  # "Excluir" a conversa so' para esta pessoa: corta o historico dela aqui e
  # zera o nao lido. O outro participante nao e tocado.
  def clear!
    now = Time.zone.now
    update!(cleared_at: now, last_read_at: now)
  end

  private

  def ensure_account_id
    self.account_id ||= chat_channel&.account_id
  end
end
