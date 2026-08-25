FactoryBot.define do
  factory :ticket do
    sequence(:title) { |n| "Ticket #{n}" }
    description { 'Descrição do ticket' }
    priority { 'medium' }
    ticket_column

    after(:build) do |ticket|
      ticket.account ||= ticket.ticket_column&.account || create(:account)
      ticket.team ||= ticket.ticket_column&.team
      # Category is required when opening a ticket and is scoped to the Mesa. A
      # Mesa provisions a default list on creation, so this reuses that rather
      # than inventing a second one.
      ticket.ticket_category ||= ticket.team&.ticket_categories&.first
      # The Mesa owns who may be assigned, so a fixture that names an assignee
      # has to put them in the Mesa for the ticket to be valid at all.
      if ticket.assignee_id.present? && ticket.team && !ticket.team.members.exists?(id: ticket.assignee_id)
        ticket.team.add_members([ticket.assignee_id])
      end
    end
  end
end
