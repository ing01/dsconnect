# Mesma regua que ja protege a aba de Cobranca da Empresa
# (`client_billing_manage`, ver `Api::V1::Accounts::CompaniesController#can_manage_billing?`) -
# Contrato e' a mesma categoria de dado sensivel (valor pago, produtos, quem assinou).
class ContractPolicy < ApplicationPolicy
  def index?
    true
  end

  def search?
    true
  end

  def show?
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
