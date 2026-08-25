class CreateTicketSlaExtensions < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_sla_extensions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      # Nullable so removing an agent never erases the extension they granted.
      t.references :user, foreign_key: true, null: true
      t.decimal :hours, precision: 6, scale: 2, null: false
      t.text :reason, null: false
      # Snapshotted so the audit trail survives later changes to `due_at`.
      t.datetime :previous_due_at
      t.datetime :new_due_at
      t.timestamps
    end
    add_index :ticket_sla_extensions, [:ticket_id, :created_at]
  end
end
