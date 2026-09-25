# Avisa a operacao que um chamado do cliente chegou na Triagem.
#
# Nao reaproveita o `NotificationBuilder`: aquele assume um `Conversation` como
# ator (`primary_actor.contact.blocked?`, checagem de acesso a conversa), e nada
# disso faz sentido para um Ticket. E o mesmo motivo pelo qual
# `Implementation::OverdueDateNotificationBuilder` existe para Project.
class Tickets::TriageNotificationBuilder
  pattr_initialize [:ticket!]

  def perform
    return unless ticket.pending_triage?

    destinatarios.each { |user| notificar(user) }
  end

  private

  # Quem tem acesso a tela de Triagem: a rota dela e aberta a administradores e
  # agentes da conta. Notificar so alguns seria escolher, aqui, uma regra que a
  # tela nao tem.
  def destinatarios
    ticket.account.users
  end

  def notificar(user)
    return if ja_avisado?(user)

    user.notifications.create!(
      notification_type: 'ticket_triage_pending',
      account: ticket.account,
      primary_actor: ticket
    )
  end

  # O mesmo chamado nao avisa duas vezes a mesma pessoa enquanto ela nao tiver
  # lido - o aviso e "ha algo na fila", e repetir nao acrescenta nada.
  def ja_avisado?(user)
    Notification.exists?(
      account_id: ticket.account_id, user_id: user.id,
      notification_type: 'ticket_triage_pending',
      primary_actor_type: 'Ticket', primary_actor_id: ticket.id,
      read_at: nil
    )
  end
end
