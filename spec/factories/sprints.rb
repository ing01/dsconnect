FactoryBot.define do
  factory :sprint do
    sequence(:name) { |n| "Sprint #{n}" }
    starts_on { Date.current.beginning_of_week }
    ends_on { Date.current.end_of_week }
    account
    team
  end
end
