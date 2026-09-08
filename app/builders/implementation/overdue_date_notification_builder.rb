# Cria a notificação de "data vencida" pra um Project (sino de notificações do
# painel, portado). Não reaproveita `NotificationBuilder` porque ele assume um
# `Conversation` como `primary_actor` (`primary_actor.contact.blocked?`,
# checagem de acesso à conversa) - nada disso faz sentido pra um Project.
class Implementation::OverdueDateNotificationBuilder
  pattr_initialize [:project!, :notification_type!]

  def perform
    return if recipient.blank?
    return if already_notified?

    recipient.notifications.create!(
      notification_type: notification_type,
      account: project.account,
      primary_actor: project
    )
  end

  private

  def recipient
    project.implementer || project.team&.manager
  end

  # Evita recriar o alerta todo dia enquanto a data continuar vencida - só
  # notifica de novo depois que a notificação anterior tiver sido lida.
  def already_notified?
    Notification.exists?(
      account_id: project.account_id,
      user_id: recipient.id,
      notification_type: notification_type,
      primary_actor_type: 'Project',
      primary_actor_id: project.id,
      read_at: nil
    )
  end
end
