class TicketCategoryPolicy < ApplicationPolicy
  # Every agent needs to read the list to open a ticket; only admins shape it,
  # the same rule the Estagios follow.
  def index?
    true
  end

  def create?
    administrator?
  end

  def update?
    administrator?
  end

  def destroy?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
