# Avisa o RESPONSAVEL do ticket que o cliente aprovou ou recusou uma proposta.
#
# So' o responsavel, nunca os seguidores: ao contrario da resposta de
# comunicacao (ver Tickets::CustomerCommunicationNotificationBuilder), quem
# precisa agir sobre uma decisao comercial e' quem responde pelo chamado.
class Tickets::ProposalNotificationBuilder
  pattr_initialize [:proposal!]

  def perform
    ticket = proposal.ticket
    return if ticket.assignee.blank?

    ticket.assignee.notifications.create!(
      notification_type: 'ticket_proposal_answered',
      account: ticket.account,
      primary_actor: ticket,
      secondary_actor: proposal
    )
  end
end
