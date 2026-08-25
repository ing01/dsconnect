class TicketColumnPolicy < ApplicationPolicy
  # Reading the Estagios is not administration: any agent needs the list to move
  # a ticket between stages. Creating/renaming/reordering stays admin-only.
  def index?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def reorder?
    @account_user.administrator?
  end
end
