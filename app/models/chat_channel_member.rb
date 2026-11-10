# A participacao de alguem numa sala, com o ponto ate onde essa pessoa leu.
class ChatChannelMember < ApplicationRecord
  belongs_to :account
  belongs_to :chat_channel
  belongs_to :user

  validates :user_id, uniqueness: { scope: :chat_channel_id }

  before_validation :ensure_account_id

  # Marca tudo como lido ate agora - e, junto, as notificacoes das mensagens da
  # sala: quem ja viu o chat nao precisa de aviso do que acabou de ler. Passa por
  # aqui tanto quem abre a sala quanto quem escreve nela.
  def mark_read!
    update!(last_read_at: Time.zone.now)
    clear_chat_notifications
  end

  # "Marcar como nao lida": volta o ponto de leitura para logo antes desta
  # mensagem, e ela (e tudo que veio depois) volta a contar como nao lida - no
  # contador do menu e nas notificacoes. Serve para lembrar de responder depois.
  def mark_unread_from!(message)
    update!(last_read_at: message.created_at - 0.000001)
    reopen_chat_notifications_from(message)
  end

  # "Excluir" a conversa so' para esta pessoa: corta o historico dela aqui e
  # zera o nao lido. O outro participante nao e tocado.
  def clear!
    now = Time.zone.now
    update!(cleared_at: now, last_read_at: now)
    clear_chat_notifications
  end

  private

  # A leitura da sala vale mesmo que a limpeza das notificacoes falhe.
  def clear_chat_notifications
    Notification::MarkInternalChatReadService.new(user: user, account: account, chat_channel: chat_channel).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
  end

  # Uma a uma, com `update!`, para o tempo real atualizar o contador e a lista.
  def reopen_chat_notifications_from(message)
    user.notifications.where(
      account: account,
      notification_type: :internal_chat_message,
      primary_actor_type: 'ChatMessage',
      primary_actor_id: chat_channel.chat_messages.where('created_at >= ?', message.created_at).select(:id)
    ).where.not(read_at: nil).find_each { |notification| notification.update!(read_at: nil) }
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
  end

  def ensure_account_id
    self.account_id ||= chat_channel&.account_id
  end
end
