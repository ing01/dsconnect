class CreateCalendarEventTickets < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_event_tickets do |t|
      t.references :calendar_event, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendar_event_tickets, [:calendar_event_id, :ticket_id], unique: true, name: 'uniq_calendar_event_ticket'
  end
end
