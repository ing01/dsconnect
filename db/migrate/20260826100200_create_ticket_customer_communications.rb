class CreateTicketCustomerCommunications < ActiveRecord::Migration[7.2]
  def change
    # Messages sent TO the customer, kept apart from TicketComment, which is the
    # team's internal thread and never leaves the account.
    create_table :ticket_customer_communications do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      # Nullable so removing an agent never erases what was sent to a customer.
      t.references :user, foreign_key: true, null: true
      t.references :contact, foreign_key: { on_delete: :nullify }, null: true
      t.string :channel, default: 'email', null: false
      # Snapshotted: the Contact's address may change later, and the record has
      # to say where the message actually went.
      t.string :to_email, null: false
      t.string :subject, null: false
      t.text :body, null: false
      # 'sent' only once the delivery actually returned; 'failed' keeps the
      # error so a retry is informed.
      t.string :status, default: 'pending', null: false
      t.text :error_message
      t.datetime :sent_at
      # Marks the message that satisfies the closing requirement.
      t.boolean :closing, default: false, null: false
      t.timestamps
    end
    add_index :ticket_customer_communications, [:ticket_id, :created_at]
    add_index :ticket_customer_communications, [:ticket_id, :closing, :status],
              name: 'index_ticket_customer_comms_on_ticket_closing_status'
  end
end
