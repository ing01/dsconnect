class SuggestionColumnPolicy < ApplicationPolicy
  # Qualquer agente ou administrador ve as colunas (precisa pra ver o quadro).
  def index?
    true
  end

  def show?
    true
  end

  def create?
    administrator? || suggestion_manager?
  end

  def update?
    administrator? || suggestion_manager?
  end

  def destroy?
    administrator? || suggestion_manager?
  end

  def reorder?
    administrator? || suggestion_manager?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def suggestion_manager?
    account_user&.permissions&.include?('suggestion_manage')
  end
end
