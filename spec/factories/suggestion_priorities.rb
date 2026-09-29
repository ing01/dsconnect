FactoryBot.define do
  factory :suggestion_priority do
    sequence(:name) { |n| "Prioridade #{n}" }
    account
  end
end
