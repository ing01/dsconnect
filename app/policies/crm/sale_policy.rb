# Mesma regra de acesso de Crm::ClientPolicy - ver o comentario la' para o
# porque de nao haver bypass de administrador aqui.
class Crm::SalePolicy < ApplicationPolicy
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
