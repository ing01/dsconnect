FactoryBot.define do
  factory :crm_generated_contract, class: 'Crm::GeneratedContract' do
    account
    template { create(:crm_contract_template, account: account) }
    client { create(:crm_client, account: account) }
    data { {} }
  end
end
