# Avisa quem acompanha o ticket (responsavel + seguidores) que o CLIENTE
# respondeu pelo Portal. Mesmo motivo do Tickets::TriageNotificationBuilder
# para nao reaproveitar o `NotificationBuilder` generico (feito para
# Conversation).
#
# Sem `ja_avisado?` de proposito, ao contrario do builder de triagem: ali a
# triagem e' um ESTADO continuo ("ha algo na fila"), aqui cada mensagem e' um
# EVENTO novo e distinto - sempre gera um aviso novo, mesmo que o anterior
# ainda esteja sem leitura.
class Tickets::CustomerCommunicationNotificationBuilder
  pattr_initialize [:communication!]

  def perform
    destinatarios.each { |user| notificar(user) }
  end

  private

  def ticket
    communication.ticket
  end

  # So' quem acompanha de verdade: o responsavel pelo chamado e quem decidiu
  # seguir (ver TicketFollower) - nunca a conta inteira, ao contrario da
  # Triagem (que e' aberta a todo agente).
  def destinatarios
    [ticket.assignee, *ticket.followers].compact.uniq
  end

  def notificar(user)
    user.notifications.create!(
      notification_type: 'ticket_customer_communication_received',
      account: ticket.account,
      primary_actor: ticket,
      secondary_actor: communication
    )
  end
end
