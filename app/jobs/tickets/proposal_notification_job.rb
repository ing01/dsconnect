# Em segundo plano: quem decidiu a proposta pela Area do Cliente nao deve
# esperar a bandeja do responsavel ser escrita para receber a resposta (mesmo
# motivo do Tickets::CustomerCommunicationNotificationJob).
class Tickets::ProposalNotificationJob < ApplicationJob
  queue_as :low

  def perform(proposal_id)
    proposal = TicketProposal.find_by(id: proposal_id)
    return if proposal.blank?

    Tickets::ProposalNotificationBuilder.new(proposal: proposal).perform
  end
end
