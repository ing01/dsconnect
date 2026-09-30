# Mesma regra do ServiceCatalog, dos Estagios e das Categorias: todo agente LE a
# lista - ela alimenta o campo do formulario de ticket -, e so administrador a
# molda.
class TicketComplexityPolicy < ApplicationPolicy
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
