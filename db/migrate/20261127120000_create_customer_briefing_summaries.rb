# Cache do "Resumo do cliente" escrito pela IA. `fingerprint` e' a assinatura do
# material enviado a IA: mensagem, ticket ou nota nova muda a assinatura e gera
# um texto novo; quem enxerga conversas diferentes tem textos diferentes.
class CreateCustomerBriefingSummaries < ActiveRecord::Migration[7.2]
  def change
    create_table :customer_briefing_summaries do |t|
      t.bigint :account_id, null: false
      # Excluir o contato (ou a empresa) leva junto o que foi escrito sobre ele.
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.references :company, null: true, foreign_key: { on_delete: :cascade }
      t.string :fingerprint, null: false
      t.jsonb :content, null: false, default: {}
      t.timestamps
    end

    add_index :customer_briefing_summaries, [:account_id, :fingerprint], unique: true,
                                                                         name: 'index_customer_briefing_summaries_on_fingerprint'
  end
end
