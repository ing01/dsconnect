class Queues::DistributionService
  def initialize(conversation)
    @conversation = conversation
    @queue = conversation.queue
  end

  def perform
    return if @queue.blank? || @queue.manual?
    return if @conversation.assignee_id.present?

    agent = next_agent
    return if agent.blank?

    @conversation.with_lock { @conversation.update!(assignee_id: agent.id) }
  end

  # Usado pelo botao "Distribuir conversas" (Ingrid, 2026-11-12) pra explicar
  # pro admin, agente por agente da Mesa, por que a fila nao conseguiu
  # escolher ninguem - mesmo criterio de `eligible_agents`, so' que sem
  # descartar quem ficou de fora.
  def diagnostics
    return [{ agent: nil, reason: :no_queue }] if @queue.blank?
    return [{ agent: nil, reason: :manual_queue }] if @queue.manual?

    members = @queue.team&.members.to_a
    return [{ agent: nil, reason: :no_team }] if @queue.team.blank?
    return [{ agent: nil, reason: :no_members }] if members.blank?

    excluded_ids = excluded_agent_ids
    lunch_blackout_ids = AccountUser.lunch_blackout_user_ids(@conversation.account_id)
    online_ids = online_agent_ids_raw

    members.map do |agent|
      if excluded_ids.include?(agent.id)
        { agent: agent, reason: :excluded }
      elsif lunch_blackout_ids.include?(agent.id)
        { agent: agent, reason: :lunch_blackout }
      elsif !online_ids.include?(agent.id)
        { agent: agent, reason: :offline }
      elsif !within_open_chats_limit?(agent)
        { agent: agent, reason: :max_open_chats_reached, open_count: inbox_open_chats_count(agent) }
      else
        { agent: agent, reason: :online, open_count: open_conversation_count(agent) }
      end
    end
  end

  private

  def next_agent
    eligible_agents.min_by { |agent| ranking_key(agent) }
  end

  # A fila distribui por Mesa, mas uma conversa de Fila sempre pertence a uma
  # caixa (WhatsApp ou Portal) - a mesma Excecao da distribuicao configurada
  # ali (Colaboradores/Automacao) precisa valer aqui tambem, senao um agente
  # marcado como excecao podia ser escolhido pela fila mesmo nunca podendo
  # ser escolhido pelo rodizio comum da inbox. Bug URGENTE relatado pela
  # Ingrid, 2026-11-11 (conversa voltando de pausa, cai na fila, fila ignora
  # a excecao).
  #
  # Precisa tambem so' considerar quem esta ONLINE agora - o rodizio da
  # inbox (`InboxAgentAvailability#available_agents`) e o legado
  # (`AutoAssignment::AgentAssignmentService#online_agent_ids`) ja' faziam
  # essa checagem; a fila era o unico caminho de distribuicao automatica que
  # ainda escolhia qualquer membro da Mesa, online ou nao (pedido da Ingrid,
  # 2026-11-12 - "só pode distribuir se ele estiver ONLINE").
  def eligible_agents
    agents = @queue.team.members.to_a
    agents = agents.reject { |agent| excluded_agent_ids.include?(agent.id) } if excluded_agent_ids.present?
    agents = agents.select { |agent| within_open_chats_limit?(agent) }

    online_ids = online_agent_ids
    agents.select { |agent| online_ids.include?(agent.id) }
  end

  def excluded_agent_ids
    inbox = @conversation.inbox
    account = @conversation.account
    ids = if inbox.whatsapp?
            account.whatsapp_auto_assignment_excluded_agent_ids
          elsif inbox.client_portal?
            account.client_portal_auto_assignment_excluded_agent_ids
          end
    Array(ids).map(&:to_i)
  end

  # Mesmo "Excecao da distribuicao" (Colaboradores/Automacao) ja aplicada ao
  # rodizio comum da inbox (`AutoAssignmentHandler#apply_distribution_exceptions`)
  # - a fila so' checava a lista de agentes excluidos, nunca o limite de
  # conversas abertas, entao um agente ja no teto continuava recebendo
  # conversa atras de conversa toda vez que "Distribuir conversas" rodava em
  # lote. Bug URGENTE relatado pela Ingrid, 2026-11-14 ("enviou um monte pros
  # agentes").
  def within_open_chats_limit?(agent)
    limit = distribution_max_open_chats
    return true unless limit.positive?

    inbox_open_chats_count(agent) < limit
  end

  def distribution_max_open_chats
    inbox = @conversation.inbox
    account = @conversation.account
    if inbox.whatsapp?
      account.whatsapp_auto_assignment_max_open_chats.to_i
    elsif inbox.client_portal?
      account.client_portal_auto_assignment_max_open_chats.to_i
    else
      0
    end
  end

  # Conta na INBOX inteira (todas as filas/conversas daquela caixa), nao so'
  # nesta fila - mesmo escopo do rodizio comum (`inbox.conversations.open`),
  # senao um agente em varias filas da mesma caixa furava o limite.
  def inbox_open_chats_count(agent)
    @conversation.inbox.conversations.open.where(assignee_id: agent.id).count
  end

  # Mesmo criterio estrito das demais atribuicoes automaticas: so' 'online'
  # conta (ocupado/away nao), e quem esta no bloqueio de almoco tambem fica
  # de fora, mesmo que a presenca diga online.
  def online_agent_ids
    lunch_blackout_ids = AccountUser.lunch_blackout_user_ids(@conversation.account_id)
    online_agent_ids_raw - lunch_blackout_ids
  end

  def online_agent_ids_raw
    online_agents = OnlineStatusTracker.get_available_users(@conversation.account_id)
    return [] if online_agents.blank?

    online_agents.select { |_key, value| value.eql?('online') }.keys.map(&:to_i)
  end

  def ranking_key(agent)
    @queue.round_robin? ? last_assigned_at(agent).to_f : open_conversation_count(agent)
  end

  # Approximates turn order without a dedicated pointer table: the agent whose
  # last assignment in this queue is oldest (or who has none yet) goes next.
  def last_assigned_at(agent)
    Conversation.where(queue_id: @queue.id, assignee_id: agent.id).maximum(:updated_at) || Time.at(0)
  end

  def open_conversation_count(agent)
    Conversation.where(queue_id: @queue.id, assignee_id: agent.id).where.not(status: :resolved).count
  end
end
