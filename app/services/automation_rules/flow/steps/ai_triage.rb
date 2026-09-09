# Niveis 3-5: a IA so faz triagem, nunca tenta resolver. Uma unica chamada
# classifica urgencia/impacto, a prioridade sai de `Tickets::HelpdeskPriority`
# (determinado pelo backend, nao pela IA), o resumo fica gravado no Ticket
# para quem for atender, e a Conversation e roteada para o time humano - esta
# etapa sempre termina em handoff, nunca segue para uma proxima.
class AutomationRules::Flow::Steps::AiTriage < AutomationRules::Flow::Steps::Base
  TRANSCRIPT_MESSAGE_LIMIT = 20

  def perform
    return handoff_on_misconfiguration if ticket.blank?

    classification = classify
    priority = resolve_priority(classification)

    ticket.update!(priority: priority, custom_attributes: (ticket.custom_attributes || {}).merge(triage_summary(classification)))
    route_conversation_to_humans(priority)

    handoff(result: summary_result(classification, priority))
  end

  private

  def ticket
    @ticket ||= run.ticket
  end

  def classify
    Captain::Llm::UrgencyImpactClassifierService.new(conversation: conversation).classify(transcript: transcript)
  end

  # Falha da IA nunca trava o fluxo: cai na prioridade padrao configuravel
  # (ou so no nivel do cliente, se nada configurado), e segue para humano do
  # mesmo jeito.
  def resolve_priority(classification)
    return fallback_priority if classification['error'].present?

    Tickets::HelpdeskPriority.ticket_priority_for(
      client_level: run.read_variable('empresa.nivel'),
      urgencia: classification['urgencia'],
      impacto: classification['impacto']
    )
  end

  def fallback_priority
    label = account.helpdesk_default_priority_on_ai_failure.presence
    return Tickets::HelpdeskPriority::TICKET_PRIORITY.fetch(label) if label.present? && Tickets::HelpdeskPriority::TICKET_PRIORITY.key?(label)

    Tickets::HelpdeskPriority.ticket_priority_for(client_level: run.read_variable('empresa.nivel'))
  end

  def triage_summary(classification)
    { 'triage_summary' => {
      'empresa' => run.read_variable('empresa.nome'),
      'cnpj' => run.read_variable('empresa.cnpj'),
      'nivel_cliente' => run.read_variable('empresa.nivel'),
      'ticket_numero' => ticket.display_id,
      'resumo_problema' => classification['resumo_problema'],
      'acao_sugerida' => classification['acao_sugerida'],
      'gerado_em' => Time.current.iso8601
    }.compact }
  end

  def route_conversation_to_humans(priority)
    team_id = params[:team_id].presence || account.helpdesk_level_3to5_team_id
    attrs = { priority: priority }
    attrs[:team_id] = team_id if team_id.present?
    conversation.update!(attrs)
  end

  def summary_result(classification, priority)
    {
      urgencia: classification['urgencia'], impacto: classification['impacto'],
      priority: priority, model: classification['model'], ai_error: classification['error']
    }.compact
  end

  def transcript
    conversation.messages
                .where(message_type: %i[incoming outgoing], private: false)
                .order(:created_at).last(TRANSCRIPT_MESSAGE_LIMIT)
                .map { |message| "#{message.incoming? ? 'Cliente' : 'Atendimento'}: #{message.content}" }
                .join("\n")
  end

  # So acontece se o fluxo pular o `create_ticket`/`find_open_ticket_*` antes
  # desta etapa - configuracao errada, nao algo que o cliente causou, mas
  # ainda assim precisa avisar e entregar para uma pessoa.
  def handoff_on_misconfiguration
    say(I18n.t('automations.flow.ai_resolve.error_message'))
    conversation.bot_handoff!(dispatch_event: false)
    handoff(result: { error: 'nenhum ticket vinculado a esta execucao' })
  end
end
