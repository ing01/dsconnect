class TicketBulkOperationItem < ApplicationRecord
  belongs_to :ticket_bulk_operation

  enum outcome: { pending: 'pending', succeeded: 'succeeded', skipped: 'skipped', failed: 'failed' }

  def push_event_data
    { ticket_id: ticket_id, display_id: display_id, outcome: outcome, reason_code: reason_code, reason: reason_message }
  end
end
