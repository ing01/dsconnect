# Nichos e sub-nichos por agente: qualquer um da conta consulta; so' o administrador altera.
class AgentNichePolicy < ApplicationPolicy
  def index?
    true
  end

  def update?
    @account_user.administrator?
  end
end
