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

  def eligible_agents
    @queue.team.members.to_a
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
