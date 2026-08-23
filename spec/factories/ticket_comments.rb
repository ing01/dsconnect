FactoryBot.define do
  factory :ticket_comment do
    ticket
    content { 'Comentário interno de teste' }

    after(:build) do |ticket_comment|
      ticket_comment.account ||= ticket_comment.ticket&.account || create(:account)
      ticket_comment.user ||= create(:user, account: ticket_comment.account)
    end
  end
end
