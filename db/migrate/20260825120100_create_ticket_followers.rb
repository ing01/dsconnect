class CreateTicketFollowers < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_followers do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    # Following twice is meaningless, and the child-ticket copy relies on the
    # database rejecting a duplicate rather than checking first.
    add_index :ticket_followers, [:ticket_id, :user_id], unique: true, name: 'index_ticket_followers_on_ticket_and_user'
  end
end
