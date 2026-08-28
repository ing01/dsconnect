class ProjectPolicy < ApplicationPolicy
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
    true
  end

  def generate_tickets?
    true
  end

  def destroy?
    account_user&.administrator?
  end
end
