class AddEventTypeToCalendarEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :calendar_events, :event_type, :integer, default: 0, null: false
  end
end
