class TeamPolicy < ApplicationPolicy
  def index?
    true
  end

  def update?
    @account_user.administrator? || department_manager? || team_manager?
  end

  def show?
    true
  end

  def create?
    @account_user.administrator? || department_manager?
  end

  def destroy?
    @account_user.administrator?
  end

  private

  def department_manager?
    @account_user&.permissions&.include?('department_manage')
  end

  def team_manager?
    record.respond_to?(:manager_id) && record.manager_id.present? && record.manager_id == user.id
  end
end
