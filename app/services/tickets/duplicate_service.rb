# "Duplicar ticket": a fresh ticket seeded from this one's content.
#
# Deliberately NOT a child - no `parent_id` is set. The two tickets are
# independent from the moment the copy exists.
#
# Only descriptive fields are carried over. The ticket number, history,
# activities, attachments, comments, linked conversations, timestamps and
# lifecycle columns (`resolved_at`, `closed_at`, `merged_into_id`) all belong to
# the original and are left behind; the copy starts open, in the first Estagio of
# the same Mesa, with a new number of its own.
class Tickets::DuplicateService
  pattr_initialize [:ticket!, :user!]

  def perform
    copy = ticket.account.tickets.create!(copied_attributes)
    copy.ticket_activities.create!(
      account_id: copy.account_id, user: user, activity_type: :duplicated,
      previous_value: ticket.display_id.to_s, meta: { ticket_id: ticket.id }
    )
    copy
  end

  private

  def copied_attributes
    column = ticket.team.ticket_columns.order(:position, :id).first || ticket.ticket_column

    {
      title: I18n.t('tickets.duplicate.title', title: ticket.title, default: "#{ticket.title} (copia)"),
      company_id: ticket.company_id,
      team: column.team,
      ticket_column: column,
      # Only when they are still a member: the Mesa owns who may be assigned.
      assignee_id: assignee_id_for(column.team)
    }.merge(opening_requirements(column.team))
  end

  # Description, category and priority are required when opening a ticket. A
  # ticket opened before those rules existed may have none of them, so the copy
  # falls back rather than refusing to duplicate a legacy ticket.
  def opening_requirements(team)
    {
      description: ticket.description.presence || ticket.title,
      ticket_category: ticket.ticket_category || team.ticket_categories.first,
      priority: ticket.priority.presence || :medium
    }
  end

  def assignee_id_for(team)
    return if ticket.assignee_id.blank?

    ticket.assignee_id if team.members.exists?(id: ticket.assignee_id)
  end
end
