# O Painel de Conversas: ver e' de quem administra a conta OU de quem tem a
# permissao `conversation_panel_view` na funcao personalizada; configurar os
# tempos e' so' de administrador.
class ConversationPanelPolicy < ApplicationPolicy
  def show?
    @account_user.administrator? ||
      @account_user.custom_role&.permissions&.include?('conversation_panel_view') || false
  end

  def update?
    @account_user.administrator?
  end
end
