FactoryBot.define do
  factory :ticket_board do
    sequence(:name) { |n| "Board #{n}" }
    account
  end
end
