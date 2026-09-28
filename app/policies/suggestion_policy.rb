class SuggestionPolicy < ApplicationPolicy
  # Transparencia combinada com a Ingrid: qualquer agente ou administrador ve
  # o quadro inteiro.
  def index?
    true
  end

  def show?
    true
  end

  # Qualquer usuario interno pode enviar uma sugestao - e o proprio ponto da
  # feature, sem trava de permissao.
  def create?
    true
  end

  def move?
    administrator? || suggestion_manager?
  end

  def destroy?
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
