json.partial! 'api/v1/models/ticket_detail', formats: [:json], resource: @ticket

# TicketPolicy#update? is `administrator? || assigned_to_user? || team_member?`.
# The detail page renders its property controls disabled when this is false,
# instead of letting the user discover the 403 through a failed save.
json.can_update policy(@ticket).update?
