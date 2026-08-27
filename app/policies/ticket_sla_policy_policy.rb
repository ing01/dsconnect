# Mesma regra dos Estagios e das Categorias: todo agente le, so administrador
# configura.
class TicketSlaPolicyPolicy < ApplicationPolicy
  def index?
    true
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
