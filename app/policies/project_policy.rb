class ProjectPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def counts?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def generate_tickets?
    true
  end

  # Faltava este metodo - toda chamada ao botao "Criar cronograma" quebrava
  # no `check_authorization` (Pundit chama `create_schedule?`, que nao
  # existia nem aqui nem em ApplicationPolicy) com um NoMethodError cru,
  # ANTES de qualquer linha do cronograma ser processada - por isso falhava
  # sempre, independente dos dados digitados. Bug relatado pela Ingrid,
  # 2026-11-14.
  def create_schedule?
    true
  end

  def cancel?
    true
  end

  def reactivate?
    true
  end

  def destroy?
    account_user&.administrator?
  end
end
