# Niveis 1-2: a IA tenta resolver de verdade, com as mesmas ferramentas que o
# Captain nativo ja usa (FaqLookupTool, HandoffTool, UpdatePriorityTool...) -
# mesma classe que o job normal do Captain chama, so que disparada pela
# triagem e nao pelo pipeline automatico da inbox.
#
# Roda por turno: a cada mensagem nova do cliente esta etapa e chamada de
# novo (espera em si mesma, como a `Ask`), ate a propria IA acionar handoff
# ou estourar o limite de turnos configurado - protecao contra a IA nunca
# decidir parar sozinha.
class AutomationRules::Flow::Steps::AiResolve < AutomationRules::Flow::Steps::Base
  DEFAULT_MAX_TURNS = 6

  def perform
    return fail_step('assistant_id nao configurado ou inexistente') if assistant.blank?
    return finish_by_handoff if turns_used >= max_turns

    increment_turns!
    runner.generate_response(message_history: message_history)

    return finish_by_handoff if runner.handoff_completed?

    wait(step['id'], result: { turn: turns_used })
  end

  private

  def assistant
    @assistant ||= account.captain_assistants.find_by(id: params[:assistant_id])
  end

  def runner
    @runner ||= Captain::Assistant::AgentRunnerService.new(assistant: assistant, conversation: conversation)
  end

  def message_history
    Captain::Conversation::MessageHistoryBuilderService.new(conversation: conversation).perform
  end

  def max_turns
    (params[:max_turns].presence || DEFAULT_MAX_TURNS).to_i
  end

  def turns_key
    "ai_resolve.#{step['id']}.turns"
  end

  def turns_used
    run.read_variable(turns_key).to_i
  end

  def increment_turns!
    run.write_variable(turns_key, turns_used + 1)
  end

  # O ticket precisa sair com uma prioridade mesmo num atendimento de nivel
  # 1/2 (requisito: o ticket continua existindo e valido mesmo quando a IA
  # resolve sozinha) - usa so o nivel do cliente, sem classificar urgencia
  #/impacto (isso e coisa da triagem de nivel 3-5, nao daqui).
  def apply_level_priority!
    return if run.ticket.blank?

    run.ticket.update!(
      priority: Tickets::HelpdeskPriority.ticket_priority_for(client_level: run.read_variable('empresa.nivel'))
    )
  end

  def finish_by_handoff
    conversation.bot_handoff!(dispatch_event: false) unless handed_off_by_captain?
    apply_level_priority!
    handoff(result: { turns: turns_used })
  end

  def handed_off_by_captain?
    @runner&.handoff_completed? == true
  end
end
