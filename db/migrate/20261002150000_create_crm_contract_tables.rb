# Geracao de contrato do Painel Comercial - modelos (.docx) sobem com
# marcadores `[[token]]` no texto; os tokens de cada modelo sao extraidos
# automaticamente no upload e guardados em `tokens` (ver
# Crm::Contracts::TokenExtractorService). `crm_generated_contracts` guarda o
# PDF gerado e os dados usados (para reimprimir/conferir depois).
#
# Campos novos em `crm_clients`: dados cadastrais e do representante legal,
# reaproveitados automaticamente ao gerar qualquer contrato do mesmo cliente
# (ver Crm::ContractTokenMapper) - preenchidos uma vez, usados em todos os
# modelos.
class CreateCrmContractTables < ActiveRecord::Migration[7.2]
  def change
    create_table :crm_contract_templates do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.jsonb :tokens, null: false, default: []

      t.timestamps
    end
    add_index :crm_contract_templates, :account_id

    create_table :crm_generated_contracts do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_contract_template_id, null: false
      t.bigint :crm_client_id, null: false
      t.bigint :crm_sale_id
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end
    add_index :crm_generated_contracts, :account_id
    add_index :crm_generated_contracts, :crm_contract_template_id
    add_index :crm_generated_contracts, :crm_client_id

    change_table :crm_clients, bulk: true do |t|
      t.string :trade_name
      t.string :state_registration
      t.string :address_street
      t.string :address_number
      t.string :address_complement
      t.string :address_neighborhood
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :representative_name
      t.string :representative_cpf
      t.date :representative_birth_date
      t.string :representative_phone
      t.string :representative_address_street
      t.string :representative_address_number
      t.string :representative_address_complement
      t.string :representative_neighborhood
      t.string :representative_city
      t.string :representative_state
      t.string :representative_zip_code
    end
  end
end
