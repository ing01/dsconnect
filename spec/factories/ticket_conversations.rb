FactoryBot.define do
  factory :ticket_conversation do
    ticket
    conversation

    after(:build) do |ticket_conversation|
      ticket_conversation.account ||= ticket_conversation.ticket&.account || create(:account)
    end
  end
end
