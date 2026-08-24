class CreateCalendarEventAttendees < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_event_attendees do |t|
      t.references :calendar_event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendar_event_attendees, [:calendar_event_id, :user_id], unique: true, name: 'uniq_calendar_event_attendee'
  end
end
