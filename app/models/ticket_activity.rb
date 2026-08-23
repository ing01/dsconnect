class TicketActivity < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :user, optional: true

  enum activity_type: {
    created: 0,
    status_changed: 1,
    column_changed: 2,
    priority_changed: 3,
    assignee_changed: 4,
    team_changed: 5,
    comment_added: 6,
    resolved: 7,
    reopened: 8,
    closed: 9,
    conversation_linked: 10,
    conversation_unlinked: 11
  }

  def push_event_data
    {
      id: id,
      ticket_id: ticket_id,
      activity_type: activity_type,
      previous_value: previous_value,
      new_value: new_value,
      meta: meta,
      user: user ? { id: user.id, name: user.name } : nil,
      created_at: created_at.to_i
    }
  end
end
