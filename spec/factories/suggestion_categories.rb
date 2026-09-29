FactoryBot.define do
  factory :suggestion_category do
    sequence(:name) { |n| "Category #{n}" }
    account
  end
end
