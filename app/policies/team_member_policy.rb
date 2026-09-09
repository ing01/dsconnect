class TeamMemberPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  # Definir em que nivel cada membro atua e configuracao da Mesa, entao segue a
  # mesma regra de incluir e remover membros.
  def update_levels?
    update?
  end

  def update?
    @account_user.administrator?
  end
end
