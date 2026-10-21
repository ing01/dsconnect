FactoryBot.define do
  factory :ticket_category do
    sequence(:name) { |n| "Categoria #{n}" }
    team
  end
end
