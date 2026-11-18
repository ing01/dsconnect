# So administrador le e molda as mensagens automaticas ao cliente: o texto fala
# em nome da empresa.
class TicketCustomerNoticeRulePolicy < ApplicationPolicy
  def index?
    administrator?
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
