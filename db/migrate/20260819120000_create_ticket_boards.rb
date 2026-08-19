class CreateTicketBoards < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_boards do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false

      t.timestamps
    end
  end
end
