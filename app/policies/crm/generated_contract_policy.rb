# Mesma regra de acesso de Crm::ClientPolicy (administrador tem acesso
# automatico; demais usuarios precisam de `commercial_manage`).
class Crm::GeneratedContractPolicy < ApplicationPolicy
  def index?
    can_manage_commercial?
  end

  def create?
    can_manage_commercial?
  end

  private

  def can_manage_commercial?
    account_user&.administrator? ||
      account_user&.custom_role&.permissions&.include?('commercial_manage') ||
      false
  end
end
