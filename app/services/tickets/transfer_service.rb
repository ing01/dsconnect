# Moves a ticket to another Mesa/Estagio while optionally reassigning status,
# priority and owner, in one transaction.
#
# The four tracked columns would otherwise each log their own TicketActivity
# (see Ticket::TRACKED_ATTRIBUTE_ACTIVITY_TYPES), scattering one operation
# across four disconnected entries. `skip_change_activities` suppresses those
# and a single `transferred` activity carries every before/after pair in `meta`,
# so the operation reads as one event and stays fully auditable.
class Tickets::TransferService
  # Kept in the order the form asks for them, which is also the order they must
  # be validated in: the Estagio and the Responsavel both depend on the Mesa.
  AUDITED_FIELDS = %w[team_id ticket_column_id status priority assignee_id].freeze

  pattr_initialize [:ticket!, :user!, :attributes!]

  def perform
    ticket.transaction do
      before = snapshot
      apply_status_transition
      apply_attributes
      log_activity(before, snapshot)
    end
    ticket
  end

  private

  def snapshot
    ticket.reload.slice(*AUDITED_FIELDS)
  end

  # Status has no generic setter: resolve!/close!/reopen!/cancel! are what write
  # `resolved_at`/`closed_at`/`cancelled_at` and their own activity, so a
  # transfer routes through them rather than assigning the column directly.
  def apply_status_transition
    target = attributes[:status].presence
    return if target.blank? || target.to_s == ticket.status

    case target.to_s
    when 'resolved' then ticket.resolve!(user)
    when 'closed' then ticket.close!(user)
    when 'cancelled' then ticket.cancel!(user)
    else ticket.reopen!(user)
    end
  end

  def apply_attributes
    column = target_column
    ticket.skip_change_activities = true
    assign_scalars
    ticket.save! if ticket.changed?
    # `move_to!` keeps `team_id` in lockstep with the Estagio and re-indexes both
    # columns; assigning `ticket_column_id` directly would leave the Mesa stale.
    ticket.move_to!(ticket_column: column, position: position_in(column)) if column != ticket.ticket_column
  ensure
    ticket.skip_change_activities = false
  end

  def assign_scalars
    ticket.assign_attributes(assignee_id: assignee_id) if attributes.key?(:assignee_id)
    ticket.assign_attributes(priority: attributes[:priority]) if attributes[:priority].present?
  end

  def target_column
    return ticket.ticket_column if attributes[:ticket_column_id].blank?

    ticket.account.ticket_columns.find(attributes[:ticket_column_id])
  end

  # An unassigned transfer is a real intent ("send it to the Mesa, nobody yet"),
  # so a blank value clears the owner instead of being ignored.
  def assignee_id
    attributes[:assignee_id].presence
  end

  def position_in(column)
    Tickets::ColumnPosition.new(ticket: ticket, column: column).by_display_id
  end

  def log_activity(before, after)
    changes = AUDITED_FIELDS.index_with { |field| [before[field], after[field]] }
                            .reject { |_field, (from, to)| from == to }
    return if changes.empty?

    ticket.ticket_activities.create!(
      account_id: ticket.account_id, user: user, activity_type: :transferred,
      previous_value: before['team_id']&.to_s, new_value: after['team_id']&.to_s,
      meta: { changes: changes }
    )
  end
end
