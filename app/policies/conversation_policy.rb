class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  # "Excluir e-mail" (limpar spam) precisa funcionar pra qualquer atendente
  # com acesso aquela caixa de e-mail, nao so' administrador - era essa a
  # trava que deixava o botao sem efeito pra quem nao e admin (pedido da
  # Ingrid, 2026-11-11). Os demais canais continuam exigindo administrador:
  # apagar ali apaga historico de atendimento de verdade, nao spam.
  def destroy?
    return true if administrator?

    record.inbox.email? && inbox_access?
  end

  def show?
    administrator? || agent_bot? || agent_can_view_conversation?
  end

  private

  def agent_can_view_conversation?
    inbox_access? || team_access?
  end

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end

  def inbox_access?
    user.inboxes.where(account_id: account&.id).exists?(id: record.inbox_id)
  end

  def team_access?
    return false if record.team_id.blank?

    user.teams.where(account_id: account&.id).exists?(id: record.team_id)
  end

  def assigned_to_user?
    record.assignee_id == user.id
  end

  def participant?
    record.conversation_participants.exists?(user_id: user.id)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
