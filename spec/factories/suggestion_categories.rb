FactoryBot.define do
  factory :suggestion_category do
    sequence(:name) { |n| "Categoria #{n}" }
    account
  end
end
