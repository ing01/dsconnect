# Niveis 1-2: a IA tenta resolver de verdade, com as mesmas ferramentas que o
# Captain nativo ja usa (FaqLookupTool, HandoffTool, UpdatePriorityTool...) -
# mesma classe que o job normal do Captain chama, so que disparada pela
# triagem e nao pelo pipeline automatico da inbox.
#
# Roda por turno: a cada mensagem nova do cliente esta etapa e chamada de
# novo (espera em si mesma, como a `Ask`), ate a propria IA acionar handoff,
# a conversa ser marcada como resolvida, ou estourar o limite de turnos
# configurado - protecao contra a IA nunca decidir parar sozinha.
#
# O ticket so e criado no final (resolvido ou encaminhado), nunca no comeco -
# um atendimento que a IA resolve sozinha nao precisa de ticket em aberto o
# tempo todo, so um registro de que aconteceu.
class AutomationRules::Flow::Steps::AiResolve < AutomationRules::Flow::Steps::Base
  include AutomationRules::Flow::Steps::Concerns::TicketBuilder

  DEFAULT_MAX_TURNS = 6

  def perform
    return handoff_on_misconfiguration if assistant.blank?
    return finish_by_resolution if conversation.resolved?
    return finish_by_handoff if turns_used >= max_turns

    increment_turns!
    runner.generate_response(message_history: message_history)

    return finish_by_resolution if conversation.resolved?
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

  # Nivel do cliente decide a prioridade base do ticket; a triagem de nivel
  # 3-5 e que classifica urgencia/impacto, nao esta etapa.
  def level_priority
    Tickets::HelpdeskPriority.ticket_priority_for(client_level: run.read_variable('empresa.nivel'))
  end

  # A IA resolveu sozinha (por conta propria, ou o cliente parou de responder
  # e o auto-resolve do Captain fechou a conversa) - ainda assim registra um
  # ticket, so que ja indo direto para resolvido, conforme pedido.
  def finish_by_resolution
    ticket = build_and_link_ticket!
    return finish_by_handoff if ticket.is_a?(Hash)

    ticket.update!(priority: level_priority)
    ticket.resolve! if ticket.open?
    stop(result: { resolved: true, turns: turns_used })
  end

  def finish_by_handoff
    conversation.bot_handoff!(dispatch_event: false) unless handed_off_by_captain?
    ticket = build_and_link_ticket!
    ticket.update!(priority: level_priority) unless ticket.is_a?(Hash)
    handoff(result: { turns: turns_used, ticket_error: ticket.is_a?(Hash) ? ticket[:error] : nil }.compact)
  end

  def handed_off_by_captain?
    @runner&.handoff_completed? == true
  end

  # Assistente apagado ou etapa mal configurada nao pode deixar o cliente
  # sem resposta nenhuma - mesma regra do `create_ticket`.
  def handoff_on_misconfiguration
    say(I18n.t('automations.flow.ai_resolve.error_message'))
    conversation.bot_handoff!(dispatch_event: false)
    handoff(result: { error: 'assistant_id nao configurado ou inexistente' })
  end
end
