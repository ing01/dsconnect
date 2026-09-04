FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Projeto #{n}" }
    team
    account { team&.account || create(:account) }
    stage { 'pendente' }
  end
end
