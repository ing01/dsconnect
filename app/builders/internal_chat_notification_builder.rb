# Quem e notificado por uma mensagem do Chat Interno.
#
# Existe ao lado do NotificationBuilder, e nao dentro dele, porque aquele decide
# acesso por Inbox/Time/papel de uma Conversation - regras que nao se aplicam
# aqui. O que cria e entrega a notificacao continua sendo o mesmo: a partir do
# `Notification`, o push segue pelo caminho de sempre.
#
# A permissao aqui e simples e estrita: so quem participa da sala.
class InternalChatNotificationBuilder
  pattr_initialize [:chat_message!]

  def perform
    return if sender.blank?

    recipients.each { |user| notify(user) }
  end

  private

  delegate :chat_channel, to: :chat_message

  def sender
    chat_message.user
  end

  # Os outros participantes da sala. Quem escreveu nao recebe aviso do proprio
  # texto, e ninguem de fora da sala e notificado - a participacao E a permissao.
  def recipients
    chat_channel.members.where.not(id: sender.id)
  end

  def notify(user)
    user.notifications.create!(
      notification_type: :internal_chat_message,
      account: chat_message.account,
      primary_actor: chat_message,
      secondary_actor: sender
    )
  rescue StandardError => e
    # Uma notificacao que falha nao pode impedir a mensagem de existir: ela ja
    # foi gravada e entregue pelo tempo real.
    ChatwootExceptionTracker.new(e, account: chat_message.account).capture_exception
  end
end
