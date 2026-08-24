class CalendarEventTicket < ApplicationRecord
  belongs_to :calendar_event
  belongs_to :ticket
end
