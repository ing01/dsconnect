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
      allowed_agent_ids = apply_distribution_exceptions(allowed_agent_ids)
      AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: allowed_agent_ids).perform
    end
  end

  # A "Excecao da distribuicao" (agentes fora do rodizio + limite de
  # conversas abertas, em Configuracoes > Caixas de Entrada > Colaboradores
  # para WhatsApp, ou Tickets > Automacao para o Portal) so' era aplicada no
  # caminho novo (`Enterprise::AutoAssignment::AssignmentService`, quando a
  # conta tem o feature `assignment_v2`). Contas sem esse feature usam este
  # caminho legado, que nunca filtrava por ela - um agente marcado como
  # excecao continuava recebendo conversas pelo rodizio comum sempre que uma
  # conversa voltava de pausa (ou era aberta direto) nessa caixa. Bug URGENTE
  # relatado pela Ingrid, 2026-11-11.
  def apply_distribution_exceptions(agent_ids)
    excluded_ids = distribution_excluded_agent_ids
    agent_ids -= excluded_ids if excluded_ids.present?

    limit = distribution_max_open_chats
    return agent_ids unless limit.positive?

    agent_ids.select { |agent_id| inbox.conversations.open.where(assignee_id: agent_id).count < limit }
  end

  def distribution_excluded_agent_ids
    return Array(account.whatsapp_auto_assignment_excluded_agent_ids) if inbox.whatsapp?
    return Array(account.client_portal_auto_assignment_excluded_agent_ids) if inbox.client_portal?

    []
  end

  def distribution_max_open_chats
    return account.whatsapp_auto_assignment_max_open_chats.to_i if inbox.whatsapp?
    return account.client_portal_auto_assignment_max_open_chats.to_i if inbox.client_portal?

    0
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
    # Conversa com fila definida (ex: triagem por IA, aguardando alguem
    # pegar na mao) nunca pode ser roubada por este rodizio generico - nem na
    # primeira vez, nem quando ela volta de uma pausa (Pausar/Snooze) pra
    # "aberta" de novo. Mesma regra que `AutoAssignment::AssignmentService`
    # ja aplica na varredura em lote (`where(queue_id: nil)`); sem isso aqui,
    # uma conversa pausada ENQUANTO ainda na fila saia da pausa e caia
    # sozinha num agente do rodizio, pulando a fila (bug relatado pela
    # Ingrid, 2026-11-10).
    return false if queue_id.present?
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
  # Portal do Cliente nao tem IA/triagem no meio (pedido da Ingrid, 2026-11-09)
  # - nunca deve ficar travado so porque OUTRA caixa (ex: WhatsApp) tem uma
  # automacao de fluxo ativa. A trava abaixo e' por conta, nao por inbox, de
  # proposito para o WhatsApp (ver comentario completo no metodo que chama
  # este); o Portal precisa ficar de fora dela.
  def pending_flow_automation?
    return false if inbox.client_portal?

    account.automation_rules.where(active: true).any?(&:flow?)
  end
end
