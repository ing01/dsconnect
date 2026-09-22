# Mesma regua de Produto/Contrato (`client_billing_manage`) - Grupo de
# Produtos so existe pra compor linhas de Contrato.
class ProductGroupPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    can_manage_billing?
  end

  def update?
    can_manage_billing?
  end

  def destroy?
    can_manage_billing?
  end

  private

  def can_manage_billing?
    @account_user.administrator? || @account_user.permissions&.include?('client_billing_manage')
  end
end
