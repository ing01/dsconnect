# Avisa os Administradores da conta que uma sugestao de melhoria nova chegou.
#
# Mesmo motivo do Tickets::TriageNotificationBuilder: nao reaproveita o
# NotificationBuilder generico (assume Conversation como ator).
class Suggestions::AdminNotificationBuilder
  pattr_initialize [:suggestion!]

  def perform
    destinatarios.each { |user| notificar(user) }
  end

  private

  def destinatarios
    suggestion.account.administrators
  end

  def notificar(user)
    user.notifications.create!(
      notification_type: 'suggestion_created',
      account: suggestion.account,
      primary_actor: suggestion
    )
  end
end
