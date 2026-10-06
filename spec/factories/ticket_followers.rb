FactoryBot.define do
  factory :ticket_follower do
    ticket
    user

    after(:build) do |follower|
      follower.account ||= follower.ticket&.account
    end
  end
end
