class Messages::NewMessageNotificationService
  pattr_initialize [:message!]

  def perform
    return unless message.notifiable?
    return if system_generated?

    notify_conversation_assignee
    notify_participating_users
  end

  private

  delegate :conversation, :sender, :account, to: :message

  # Respostas automaticas, campanhas e disparos do sistema saem sem remetente.
  # Notificar o responsavel sobre o que o proprio sistema respondeu gerava um
  # segundo push logo depois do aviso legitimo da mensagem do cliente - dois
  # avisos para a mesma conversa, com segundos de diferenca.
  #
  # Mensagem de saida de um agente continua notificando: ali o remetente e um
  # User, e o colega precisa saber que alguem respondeu.
  def system_generated?
    message.outgoing? && sender.blank?
  end

  def notify_conversation_assignee
    return if conversation.assignee.blank?
    return if already_notified?(conversation.assignee)
    return if conversation.assignee == sender

    NotificationBuilder.new(
      notification_type: 'assigned_conversation_new_message',
      user: conversation.assignee,
      account: account,
      primary_actor: message.conversation,
      secondary_actor: message
    ).perform
  end

  def notify_participating_users
    participating_users = conversation.conversation_participants.map(&:user)
    participating_users -= [sender] if sender.is_a?(User)

    participating_users.uniq.each do |participant|
      next if already_notified?(participant)

      NotificationBuilder.new(
        notification_type: 'participating_conversation_new_message',
        user: participant,
        account: account,
        primary_actor: message.conversation,
        secondary_actor: message
      ).perform
    end
  end

  # The user could already have been notified via a mention or via assignment
  # So we don't need to notify them again
  def already_notified?(user)
    conversation.notifications.exists?(user: user, secondary_actor: message)
  end
end
