class CreateTicketColumns < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_columns do |t|
      t.references :ticket_board, null: false, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :ticket_columns, [:ticket_board_id, :position]
  end
end
