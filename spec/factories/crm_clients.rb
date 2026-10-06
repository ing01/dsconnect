FactoryBot.define do
  factory :crm_client, class: 'Crm::Client' do
    account
    sequence(:name) { |n| "Cliente #{n}" }
    cnpj { '12.345.678/0001-99' }
    trade_name { 'Nome Fantasia' }
    email { 'cliente@exemplo.com.br' }
    phone { '(11) 99999-0000' }
    representative_name { 'Representante Original' }
    representative_cpf { '111.111.111-11' }
  end
end
