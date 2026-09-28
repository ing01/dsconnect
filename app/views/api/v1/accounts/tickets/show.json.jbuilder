json.partial! 'api/v1/models/ticket_detail', formats: [:json], resource: @ticket

# TicketPolicy#update? is `administrator? || assigned_to_user? || team_member?`.
# The detail page renders its property controls disabled when this is false,
# instead of letting the user discover the 403 through a failed save.
json.can_update policy(@ticket).update?

# Extending a deadline is gated more tightly than ordinary ticket handling
# (admin or the assignee), so the menu is told separately rather than inferring
# it from `can_update`.
json.can_add_sla_hours policy(@ticket).add_sla_hours?

# TicketPolicy#destroy? is administrator-only.
json.can_destroy policy(@ticket).destroy?

# The children count decides whether the delete confirmation offers a choice
# (delete them together or keep them, unlinked) or is a plain confirm.
json.children_count @ticket.children.count
