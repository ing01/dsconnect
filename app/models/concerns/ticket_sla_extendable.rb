# The ticket's own deadline and the manual extensions applied to it.
#
# The SLA that already exists in this product (AppliedSla) hangs off a
# Conversation and computes its due dates on the fly from it - there is no
# stored deadline to shift, and a ticket opened straight from the Kanban has no
# conversation at all. So a ticket carries `due_at` itself.
module TicketSlaExtendable
  extend ActiveSupport::Concern

  included do
    has_many :ticket_sla_extensions, dependent: :destroy
  end

  # A ticket with no deadline yet gets one counted from now, which is what
  # "add 4 hours" means when nothing was promised before.
  def extend_due_at!(hours:, reason:, user: Current.user)
    transaction do
      previous = due_at
      new_due_at = (previous || Time.zone.now) + hours.to_f.hours
      update!(due_at: new_due_at)

      extension = ticket_sla_extensions.create!(
        account_id: account_id, user: user, hours: hours, reason: reason,
        previous_due_at: previous, new_due_at: new_due_at
      )
      log_sla_extension_activity(extension, user)
      extension
    end
  end

  private

  def log_sla_extension_activity(extension, user)
    ticket_activities.create!(
      account_id: account_id, user: user, activity_type: :sla_hours_added,
      previous_value: extension.previous_due_at&.iso8601, new_value: extension.new_due_at&.iso8601,
      meta: { hours: extension.hours.to_f, reason: extension.reason }
    )
  end
end
