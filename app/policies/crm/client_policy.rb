# Administrador da conta tem acesso automatico; qualquer outro usuario
# precisa da permissao `commercial_manage` (custom_role) atribuida
# explicitamente pela Ingrid.
class Crm::ClientPolicy < ApplicationPolicy
  def index?
    can_manage_commercial?
  end

  def show?
    can_manage_commercial?
  end

  def create?
    can_manage_commercial?
  end

  def update?
    can_manage_commercial?
  end

  def change_representative?
    update?
  end

  def destroy?
    can_manage_commercial?
  end

  private

  def can_manage_commercial?
    account_user&.administrator? ||
      account_user&.custom_role&.permissions&.include?('commercial_manage') ||
      false
  end
end
