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

  # Edicao em massa mexe em muitas Empresas de uma vez - so administrador.
  def bulk_update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

end
