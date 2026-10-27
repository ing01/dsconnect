# Avisa o RESPONSAVEL do ticket que o cliente aprovou ou recusou uma proposta.
#
# So' o responsavel, nunca os seguidores: ao contrario da resposta de
# comunicacao (ver Tickets::CustomerCommunicationNotificationBuilder), quem
# precisa agir sobre uma decisao comercial e' quem responde pelo chamado.
#
# A proposta pode valer para varios tickets: cada responsavel recebe UM aviso,
# que abre o primeiro ticket dele entre os vinculados (quem responde por dois
# deles nao recebe dois).
class Tickets::ProposalNotificationBuilder
  pattr_initialize [:proposal!]

  def perform
    ticket_by_assignee.each do |assignee, ticket|
      assignee.notifications.create!(
        notification_type: 'ticket_proposal_answered',
        account: ticket.account,
        primary_actor: ticket,
        secondary_actor: proposal
      )
    end
  end

  private

  def ticket_by_assignee
    proposal.tickets.includes(:assignee).each_with_object({}) do |ticket, by_assignee|
      by_assignee[ticket.assignee] ||= ticket if ticket.assignee
    end
  end
end
