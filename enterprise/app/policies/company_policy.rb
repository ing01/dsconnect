class CompanyPolicy < ApplicationPolicy
  def index?
    true
  end

  def search?
    true
  end

  def cnpj_lookup?
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

  def avatar?
    update?
  end

  def destroy_custom_attributes?
    update?
  end

  def destroy?
    @account_user.administrator?
  end

  # Mesma barreira de billing_amount (Companies Controller#can_manage_billing?)
  # ja que o recalculo depende diretamente dele.
  def recalculate_priorities?
    @account_user.administrator? || @account_user.permissions&.include?('client_billing_manage')
  end
end
