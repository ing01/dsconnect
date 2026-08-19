class CreateTicketConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_conversations do |t|
      t.references :account, null: false, index: true
      t.references :ticket, null: false, index: true
      t.references :conversation, null: false, index: true

      t.timestamps
    end

    add_index :ticket_conversations, [:ticket_id, :conversation_id], unique: true, name: 'index_ticket_conversations_on_ticket_and_conversation'
  end
end
