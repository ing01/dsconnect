FactoryBot.define do
  factory :project_module do
    sequence(:name) { |n| "Módulo #{n}" }
    account
  end
end
