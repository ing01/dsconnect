# Log da Gestao de clientes: cada alteracao em massa vira uma linha, com o
# progresso e, se houver, os clientes que nao puderam ser alterados e o motivo.
class CreateCompanyBulkUpdates < ActiveRecord::Migration[7.2]
  def change
    create_table :company_bulk_updates do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :status, null: false, default: 'queued'
      t.integer :total, null: false, default: 0
      t.integer :processed_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.jsonb :summary, null: false, default: []
      t.jsonb :failures, null: false, default: []
      t.string :error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :company_bulk_updates, [:account_id, :created_at]
  end
end
