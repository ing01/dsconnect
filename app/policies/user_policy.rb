class UserPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  # Definir a senha de outra pessoa e privilegio de administrador, como criar e
  # remover agente.
  def reset_password?
    @account_user.administrator?
  end

  def bulk_create?
    @account_user.administrator?
  end
end
