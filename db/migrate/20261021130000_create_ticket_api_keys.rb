class CreateTicketApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_api_keys do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :ticket_api_keys, :token, unique: true
  end
end
