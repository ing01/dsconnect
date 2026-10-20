class AddReminderMinutesBeforeToCalendarEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :calendar_events, :reminder_minutes_before, :integer
  end
end
