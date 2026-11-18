FactoryBot.define do
  factory :client_announcement do
    account
    sequence(:title) { |n| "Aviso #{n}" }
    body { 'Texto do aviso' }
    kind { 'info' }
    audience { 'all' }
    active { true }
  end
end
