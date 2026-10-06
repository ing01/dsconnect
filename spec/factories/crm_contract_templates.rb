FactoryBot.define do
  factory :crm_contract_template, class: 'Crm::ContractTemplate' do
    account
    sequence(:name) { |n| "Modelo #{n}" }
    tokens { [] }
  end
end
