class CreateTickets < ActiveRecord::Migration[7.1]
  def change
    create_table :tickets do |t|
      t.references :account, null: false, index: true
      t.references :ticket_column, null: false, index: true
      t.bigint :assignee_id
      t.bigint :team_id

      t.string :title, null: false
      t.text :description
      t.integer :priority
      t.integer :position, null: false, default: 0
      t.jsonb :custom_attributes, default: {}

      t.timestamps
    end

    add_index :tickets, :assignee_id
    add_index :tickets, :team_id
    add_index :tickets, [:ticket_column_id, :position]
  end
end
