module InboxAgentAvailability
  extend ActiveSupport::Concern

  def available_agents
    online_agent_ids = fetch_online_agent_ids - lunch_blackout_agent_ids
    return inbox_members.none if online_agent_ids.empty?

    inbox_members
      .joins(:user)
      .where(users: { id: online_agent_ids })
      .includes(:user)
  end

  def member_ids_with_assignment_capacity
    member_ids - lunch_blackout_agent_ids
  end

  private

  def fetch_online_agent_ids
    OnlineStatusTracker.get_available_users(account_id)
                       .select { |_key, value| value.eql?('online') }
                       .keys
                       .map(&:to_i)
  end

  # Quem tem horario de almoco cadastrado (AccountUser#lunch_blackout_now?) e
  # esta dentro da janela de bloqueio agora - fica de fora da distribuicao
  # automatica sem precisar ficar "offline" pra isso. Nao afeta conversas ja
  # atribuidas a essa pessoa, so impede novas atribuicoes.
  def lunch_blackout_agent_ids
    AccountUser.lunch_blackout_user_ids(account_id)
  end
end

InboxAgentAvailability.prepend_mod_with('InboxAgentAvailability')
