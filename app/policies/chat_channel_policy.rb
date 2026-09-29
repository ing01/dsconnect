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

  # As regras de verdade das duas estao no controller, porque dependem da sala e
  # da mensagem: quem pode escrever num canal de aviso, e quem pode apagar o que.
  # Aqui so nao se barra ninguem por papel.
  def update?
    true
  end

  def destroy?
    true
  end
end
