class InboxPolicy < ApplicationPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      user.assigned_inboxes
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)

    # A caixa "Portal do Cliente" e' criada pelo sistema, sem ninguem como membro. Sem isto, so'
    # administradores conseguiam abrir conversa com um cliente do Portal: para os demais
    # atendentes a caixa era filtrada e aparecia "Nao ha caixas de entrada disponiveis".
    return true if record.client_portal?

    Current.user.assigned_inboxes.include? record
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def message_templates?
    true
  end

  def campaigns?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def set_agent_bot?
    @account_user.administrator?
  end

  def avatar?
    @account_user.administrator?
  end

  def sync_templates?
    @account_user.administrator?
  end

  def whatsapp_business_management_token?
    @account_user.administrator?
  end

  def health?
    @account_user.administrator?
  end

  def reset_secret?
    @account_user.administrator?
  end

  def enable_whatsapp_calling?
    @account_user.administrator?
  end

  def disable_whatsapp_calling?
    @account_user.administrator?
  end

  def set_inbound_calls?
    @account_user.administrator?
  end
end
