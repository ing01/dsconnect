FactoryBot.define do
  factory :ticket do
    sequence(:title) { |n| "Ticket #{n}" }
    description { 'Descrição do ticket' }
    priority { 'medium' }
    ticket_column

    after(:build) do |ticket|
      ticket.account ||= ticket.ticket_column&.account || create(:account)
      ticket.team ||= ticket.ticket_column&.team
    end
  end
end
