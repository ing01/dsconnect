class SprintPolicy < ApplicationPolicy
  # Ler a lista de Sprints e' o mesmo nivel de acesso que ler o quadro de
  # tickets da Mesa - qualquer agente.
  def index?
    true
  end

  # Quem organiza o Backlog e' a propria Mesa (admin ou membro), e nao so' um
  # administrador - e' trabalho do dia a dia do time, nao configuracao.
  def create?
    administrator? || team_member?
  end

  def update?
    administrator? || team_member?
  end

  def activate?
    update?
  end

  def conclude?
    update?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def team_member?
    record.team.present? && record.team.members.exists?(id: user.id)
  end
end
