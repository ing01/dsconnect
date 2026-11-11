FactoryBot.define do
  factory :ticket_timer do
    ticket
    account { ticket&.account || create(:account) }
    user { create(:user, account: account) }
    category { 'implantacao' }
    accumulated_seconds { 0 }
    started_at { nil }

    trait :running do
      started_at { Time.current }
    end
  end
end
