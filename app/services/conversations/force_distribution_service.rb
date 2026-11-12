# Botao "Distribuir conversas" (Configuracoes > Tickets > Distribuicao
# Automatica), visivel so' para administradores - pedido da Ingrid,
# 2026-11-12: "forçar a distribuição, caso não faça sozinho e que exiba
# amigavelmente caso não funcione, os motivos".
#
# Escopo: conversas abertas, sem atendente, que pertencem a uma Fila (o
# caminho de distribuicao automatica realmente usado hoje - praticamente
# todo WhatsApp passa pela triagem de IA e cai numa Fila). Conversas sem
# fila (rodizio direto da inbox) nao sao tocadas aqui por este botao.
class Conversations::ForceDistributionService
  AgentOutcome = Struct.new(:agent_name, :reason_key, :reason_params, keyword_init: true)
  ConversationOutcome = Struct.new(:display_id, :assigned, :agent_name, :agent_outcomes, keyword_init: true)

  def initialize(account)
    @account = account
  end

  def perform
    outcomes = candidate_conversations.map { |conversation| process(conversation) }

    {
      total: outcomes.size,
      assigned_count: outcomes.count(&:assigned),
      unassigned: outcomes.reject(&:assigned)
    }
  end

  private

  def candidate_conversations
    @account.conversations.open.where(assignee_id: nil).where.not(queue_id: nil).includes(queue: :team)
  end

  def process(conversation)
    service = Queues::DistributionService.new(conversation)
    service.perform
    conversation.reload

    if conversation.assignee_id.present?
      ConversationOutcome.new(display_id: conversation.display_id, assigned: true, agent_name: conversation.assignee&.name, agent_outcomes: [])
    else
      ConversationOutcome.new(display_id: conversation.display_id, assigned: false, agent_name: nil, agent_outcomes: agent_outcomes_for(service))
    end
  end

  def agent_outcomes_for(service)
    service.diagnostics.map { |diagnostic| to_agent_outcome(diagnostic) }
  end

  def to_agent_outcome(diagnostic)
    agent = diagnostic[:agent]

    case diagnostic[:reason]
    when :online
      AgentOutcome.new(agent_name: agent.name, reason_key: 'online_load', reason_params: { count: diagnostic[:open_count] })
    when :offline
      AgentOutcome.new(agent_name: agent.name, reason_key: 'offline', reason_params: {})
    when :excluded
      AgentOutcome.new(agent_name: agent.name, reason_key: 'excluded', reason_params: {})
    when :lunch_blackout
      AgentOutcome.new(agent_name: agent.name, reason_key: 'lunch_blackout', reason_params: {})
    when :no_team
      AgentOutcome.new(agent_name: nil, reason_key: 'no_team', reason_params: {})
    when :no_members
      AgentOutcome.new(agent_name: nil, reason_key: 'no_members', reason_params: {})
    when :manual_queue
      AgentOutcome.new(agent_name: nil, reason_key: 'manual_queue', reason_params: {})
    when :no_queue
      AgentOutcome.new(agent_name: nil, reason_key: 'no_queue', reason_params: {})
    end
  end
end
