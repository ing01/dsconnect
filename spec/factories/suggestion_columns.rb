FactoryBot.define do
  factory :suggestion_column do
    sequence(:name) { |n| "Column #{n}" }
    account
  end
end
