FactoryBot.define do
  factory :suggestion do
    sequence(:title) { |n| "Suggestion #{n}" }
    description { 'A description' }
    suggestion_column
    user

    after(:build) do |suggestion|
      suggestion.account ||= suggestion.suggestion_column&.account || create(:account)
    end
  end
end
