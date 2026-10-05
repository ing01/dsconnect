# A avaliacao mensal, do lado interno - so LEITURA. Quem grava e o Portal, nao
# a equipe; aqui so existe consultar o resultado.
class MonthlySatisfactionSurveyPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end
end
