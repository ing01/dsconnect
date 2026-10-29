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

  # Ajustar o canal (nome/descricao/fixar/moderadores) tem a regra de verdade
  # no controller (`administrator?`) - aqui so' garante participacao, ja
  # assegurada por `fetch_channel`/`visible_channels`.
  def update?
    true
  end

  # Excluir o canal e mexer em quem participa dele e' coisa de quem o criou ou
  # de um Administrador - nao de qualquer membro. Ja a conversa privada
  # (`direct`) pode ser excluida por quem participa dela (ela some so' para quem
  # excluiu - ver ChatChannelsController#destroy): quem abriu com a pessoa errada
  # ou quer limpar a lista.
  def destroy?
    return direct_participant? if record.is_a?(ChatChannel) && record.direct?

    channel_manager?
  end

  def add_member?
    channel_manager?
  end

  def remove_member?
    channel_manager?
  end

  private

  def direct_participant?
    record.chat_channel_members.exists?(user_id: user.id)
  end

  def channel_manager?
    return false unless record.is_a?(ChatChannel) && record.channel?

    account_user&.administrator? || record.created_by_id == user.id
  end
end
