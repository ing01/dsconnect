# Ao contrario da maioria das policies deste app, aqui NAO ha bypass para
# administrador - dado comercial e' restrito a quem a Ingrid atribuir
# explicitamente o papel/permissao `commercial_manage` (custom_role), mesmo
# que a pessoa seja administradora da conta por outro motivo.
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

  def destroy?
    can_manage_commercial?
  end

  private

  def can_manage_commercial?
    account_user&.custom_role&.permissions&.include?('commercial_manage') || false
  end
end
