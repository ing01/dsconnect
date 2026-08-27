# Todo agente usa o Chat Interno; o que limita o acesso nao e papel, e
# participacao: as consultas do controller partem de `ChatChannel.for_user`,
# entao uma sala de que a pessoa nao participa nao chega ate aqui.
class ChatChannelPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def direct?
    true
  end

  def read?
    true
  end
end
