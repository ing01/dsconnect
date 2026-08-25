class CreateTicketAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_attachments do |t|
      t.references :account, null: false, index: true
      t.references :ticket, null: false, index: true
      # Nullable so removing an agent never cascades into deleting the files
      # they uploaded.
      t.references :user, null: true, index: true

      t.timestamps
    end

    add_index :ticket_attachments, [:ticket_id, :created_at]
  end
end
