FactoryBot.define do
  factory :suggestion_priority do
    sequence(:name) { |n| "Priority #{n}" }
    account
  end
end
