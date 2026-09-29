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

  # Excluir o canal e mexer em quem participa dele e' coisa de quem o criou ou
  # de um Administrador - nao de qualquer membro. Uma conversa privada (`direct`)
  # nunca passa por aqui: nao tem essas acoes na tela, e o controller sempre
  # busca via `for_user`, entao so' chegaria um `record` de canal mesmo.
  def destroy?
    channel_manager?
  end

  def add_member?
    channel_manager?
  end

  def remove_member?
    channel_manager?
  end

  private

  def channel_manager?
    return false unless record.is_a?(ChatChannel) && record.channel?

    account_user&.administrator? || record.created_by_id == user.id
  end
end
