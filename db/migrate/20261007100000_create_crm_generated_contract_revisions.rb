# Guarda a versao ANTERIOR (dados + PDF/DOCX) de um contrato ja gerado,
# sempre que ele e' regenerado - por ora, so acontece na troca de
# representante do cliente (ver Crm::Contracts::RegenerationService). Sem
# isso, trocar o representante apagaria o contrato com o representante
# antigo sem deixar rastro.
class CreateCrmGeneratedContractRevisions < ActiveRecord::Migration[7.2]
  def change
    create_table :crm_generated_contract_revisions do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_generated_contract_id, null: false
      t.jsonb :data, null: false, default: {}
      t.string :reason

      t.timestamps
    end
    add_index :crm_generated_contract_revisions, :account_id
    add_index :crm_generated_contract_revisions, :crm_generated_contract_id
  end
end
