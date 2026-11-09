# Operacoes em lote sobre tickets (painel da Busca detalhada). Cada operacao
# guarda o que foi pedido e, por ticket, o resultado e o estado anterior - a
# base do relatorio, de "tentar de novo os que falharam" e do desfazer.
class CreateTicketBulkOperations < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_bulk_operations do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false
      t.string :action, null: false
      t.jsonb :params, null: false, default: {}
      t.jsonb :filters, null: false, default: {}
      t.string :status, null: false, default: 'pending'
      t.integer :total, null: false, default: 0
      t.integer :succeeded, null: false, default: 0
      t.integer :skipped, null: false, default: 0
      t.integer :failed, null: false, default: 0
      t.bigint :undo_of_id
      t.datetime :undone_at
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :ticket_bulk_operation_items do |t|
      t.references :ticket_bulk_operation, null: false, index: true
      t.bigint :ticket_id, null: false
      t.integer :display_id
      t.string :outcome, null: false, default: 'pending'
      t.string :reason_code
      t.string :reason_message
      t.jsonb :before, null: false, default: {}
      t.timestamps
    end
    add_index :ticket_bulk_operation_items, :ticket_id
  end
end
