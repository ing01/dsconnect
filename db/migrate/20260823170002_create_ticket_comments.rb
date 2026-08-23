class CreateTicketComments < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_comments do |t|
      t.references :account, null: false, index: true
      t.references :ticket, null: false, index: true
      t.references :user, null: false, index: true
      t.text :content, null: false

      t.timestamps
    end

    add_index :ticket_comments, [:ticket_id, :created_at]
  end
end
