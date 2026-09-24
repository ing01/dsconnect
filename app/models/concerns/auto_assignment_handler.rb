module AutoAssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    after_save :run_auto_assignment
  end

  private

  def run_auto_assignment
    # Assignment V2: Also trigger assignment when conversation is resolved or snoozed,
    # bypassing the open-only condition so the AssignmentJob can redistribute capacity.
    return unless conversation_status_changed_to_open? || conversation_status_changed_to_resolved_or_snoozed?
    return unless should_run_auto_assignment?

    if inbox.auto_assignment_v2_enabled?
      # Coalesces bursts of triggers per inbox. Fine if the job runs even when the
      # surrounding save rolls back: it only scans the inbox's current unassigned
      # conversations, so running it for an uncommitted change is harmless.
      AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id)
    else
      # Use legacy assignment system
      # If conversation has a team, only consider team members for assignment
      allowed_agent_ids = team_id.present? ? team_member_ids_with_capacity : inbox.member_ids_with_assignment_capacity
      AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: allowed_agent_ids).perform
    end
  end

  def conversation_status_changed_to_resolved_or_snoozed?
    inbox.auto_assignment_v2_enabled? && saved_change_to_status? && (resolved? || snoozed?)
  end

  def team_member_ids_with_capacity
    return [] if team.blank? || team.allow_auto_assign.blank?

    inbox.member_ids_with_assignment_capacity & team.members.ids
  end

  def should_run_auto_assignment?
    return false unless inbox.enable_auto_assignment?
    # Tem que vir ANTES do atalho de resolvido/suspenso logo abaixo - sem
    # isso, uma conversa dentro do fluxo de triagem que fosse resolvida ou
    # suspensa furava a trava (o atalho devolvia `true` direto, sem nunca
    # chegar a checar `pending_flow_automation?`).
    return false if pending_flow_automation?
    # Assignment V2: Resolved/snoozed conversations still have an assignee, so bypass the
    # assignee-blank check below. The AssignmentJob needs to run to rebalance assignments.
    return true if conversation_status_changed_to_resolved_or_snoozed?
    return false if assignee_agent_bot_id.present?

    # run only if assignee is blank or doesn't have access to inbox
    assignee.blank? || inbox.members.exclude?(assignee)
  end

  # Este `after_save` roda sincrono, ANTES do listener que dispara o fluxo
  # automatico de triagem (que so comeca depois do commit, via evento
  # `conversation_created`/`message_created`). Nesse instante a conversa ainda
  # nao tem `AutomationFlowRun` nenhum - excluir por isso (como
  # `AutoAssignment::AssignmentService` ja faz na varredura em lote) nao
  # adianta aqui, porque a execucao ainda nem existe. A unica forma de nao
  # perder a corrida e verificar ANTES se a conta tem alguma automacao com
  # fluxo ativa - se tiver, o roteamento (Mesa/Fila/prioridade) fica por conta
  # dela, nunca desta atribuicao generica da inbox.
  def pending_flow_automation?
    account.automation_rules.where(active: true).any?(&:flow?)
  end
end
