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
  def eligible_agents
    agents = @queue.team.members.to_a
    return agents if excluded_agent_ids.blank?

    agents.reject { |agent| excluded_agent_ids.include?(agent.id) }
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
