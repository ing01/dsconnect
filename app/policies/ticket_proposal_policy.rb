class TicketProposalPolicy < ApplicationPolicy
  def index?
    true
  end

  def defaults?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end

  def pdf?
    true
  end
end
