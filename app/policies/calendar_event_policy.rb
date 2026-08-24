class CalendarEventPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    administrator? || creator? || team_member?
  end

  def destroy?
    update?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def creator?
    record.created_by_id.present? && record.created_by_id == user.id
  end

  def team_member?
    record.team.members.exists?(id: user.id)
  end
end
