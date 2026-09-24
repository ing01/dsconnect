module AssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    before_save :ensure_assignee_is_from_team
    after_commit :notify_assignment_change, :process_assignment_changes
  end

  private

  def ensure_assignee_is_from_team
    return unless team_id_changed?
    return if assignee_agent_bot_id.present?

    validate_current_assignee_team
    self.assignee ||= find_assignee_from_team
  end

  def validate_current_assignee_team
    self.assignee_id = nil if team&.members&.exclude?(assignee)
  end

  # Corrida encontrada em producao (2026-09-24): a triagem por IA sempre muda
  # o `team_id` da conversa (`route_conversation_to_humans!`), o que disparava
  # ESTE metodo no MESMO save - escolhendo um agente do time por rodizio
  # simultaneamente a conversa entrar na fila manual. Nao aparecia em log
  # nenhum (nao e job, nao e request separada) porque roda inline dentro do
  # mesmo `update!` da triagem. Mesma trava das demais atribuicoes
  # automaticas: com uma automacao de fluxo ativa, o time so muda a conversa
  # de mesa, nunca escolhe um dono sozinho.
  def find_assignee_from_team
    return if team&.allow_auto_assign.blank?
    return if pending_flow_automation?

    team_members_with_capacity = inbox.member_ids_with_assignment_capacity & team.members.ids
    ::AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: team_members_with_capacity).find_assignee
  end

  def notify_assignment_change
    {
      ASSIGNEE_CHANGED => -> { saved_change_to_assignee_id? || saved_change_to_assignee_agent_bot_id? },
      TEAM_CHANGED => -> { saved_change_to_team_id? }
    }.each do |event, condition|
      condition.call && dispatcher_dispatch(event, previous_changes)
    end
  end

  def process_assignment_changes
    process_assignment_activities
  end

  def process_assignment_activities
    user_name = Current.user.name if Current.user.present?
    if saved_change_to_team_id?
      create_team_change_activity(user_name)
    elsif saved_change_to_assignee_id?
      create_assignee_change_activity(user_name)
    end
  end

  def self_assign?(assignee_id)
    assignee_id.present? && Current.user&.id == assignee_id
  end
end
