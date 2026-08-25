class TicketAttachmentPolicy < ApplicationPolicy
  def index?
    true
  end

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
