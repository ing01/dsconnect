FactoryBot.define do
  factory :ticket_complexity do
    sequence(:name) { |n| "Complexidade #{n}" }
    account

    # A Mesa em que este nivel fica disponivel. Sem ela, o nivel existe mas
    # nenhuma Mesa o oferece - que e o estado que a matriz configura.
    transient do
      teams { [] }
    end

    after(:create) do |complexity, evaluator|
      complexity.replace_teams!(evaluator.teams.map(&:id)) if evaluator.teams.present?
    end
  end
end
