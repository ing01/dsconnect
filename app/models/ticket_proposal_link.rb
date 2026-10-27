# A ligacao entre uma proposta e um dos tickets a que ela pertence.
class TicketProposalLink < ApplicationRecord
  belongs_to :ticket_proposal
  belongs_to :ticket

  validates :ticket_id, uniqueness: { scope: :ticket_proposal_id }
end
