class TicketFollowerPolicy < ApplicationPolicy
  def index?
    true
  end

  # Anyone who can see a ticket may follow it - watching a ticket grants no
  # rights over it. Removing someone else's follow is a moderation action.
  def create?
    true
  end

  def destroy?
    administrator? || record.user_id == user.id
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
