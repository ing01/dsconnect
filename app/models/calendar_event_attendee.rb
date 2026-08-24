class CalendarEventAttendee < ApplicationRecord
  belongs_to :calendar_event
  belongs_to :user
end
