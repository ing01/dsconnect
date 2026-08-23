FactoryBot.define do
  factory :ticket_column do
    sequence(:name) { |n| "Column #{n}" }
    team
  end
end
