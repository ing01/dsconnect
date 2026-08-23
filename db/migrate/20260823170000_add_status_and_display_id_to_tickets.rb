class AddStatusAndDisplayIdToTickets < ActiveRecord::Migration[7.1]
  def change
    # Lifecycle status of the ticket, decoupled from the Kanban column
    # (ticket_column represents a workflow stage/queue, status represents
    # whether the demand has been resolved/closed).
    add_column :tickets, :status, :integer, null: false, default: 0
    add_column :tickets, :display_id, :integer
    add_column :tickets, :resolved_at, :datetime
    add_column :tickets, :closed_at, :datetime

    add_index :tickets, :status
    add_index :tickets, [:account_id, :display_id], unique: true
  end
end
