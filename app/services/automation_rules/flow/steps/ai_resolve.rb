# Niveis 1-2: a IA tenta resolver de verdade, com as mesmas ferramentas que o
# Captain nativo ja usa (FaqLookupTool, HandoffTool, UpdatePriorityTool...) -
# mesma classe que o job normal do Captain chama, so que disparada pela
# triagem e nao pelo pipeline automatico da inbox.
#
# Diferente do job nativo do Captain (`Captain::Conversation::ResponseBuilderJob`),
# esta etapa e quem tem que publicar a resposta como mensagem de verdade na
# conversa - `generate_response` so calcula o texto, nao publica nada sozinho.
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
  include AutomationRules::Flow::Steps::Concerns::HumanRouting

  DEFAULT_MAX_TURNS = 6

  def perform
    return handoff_on_misconfiguration if assistant.blank?
    return finish_by_resolution if conversation.resolved?
    return finish_by_handoff if turns_used >= max_turns

    increment_turns!
    response = runner.generate_response(message_history: message_history)

    return finish_by_resolution if conversation.resolved?
    return finish_by_handoff if runner.handoff_completed?

    post_ai_reply!(response)
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

  # O mesmo que `Captain::Conversation::MessageBuilder#create_messages` faz no
  # job nativo - sem isso, a IA "responde" internamente mas o cliente nunca
  # ve nada, e a conversa fica muda ate estourar o limite de turnos.
  def post_ai_reply!(response)
    return if response.blank?

    response_parts = Captain::Assistant::ResponseParts.from_response(response)
    content = response_parts.customer_message_content(citation_urls: assistant.trusted_citation_urls(runner.last_run_result))
    return if content.blank?

    conversation.messages.create!(
      message_type: :outgoing, account_id: account.id, inbox_id: conversation.inbox_id,
      sender: assistant, content: content,
      additional_attributes: { agent_name: response['agent_name'] }.compact
    )
    account.increment_response_usage
  end

  # O texto que a IA gerou no turno do handoff nao vai para o cliente - o
  # produto sempre mostra a mensagem de transferencia configurada no lugar
  # (mesma regra do job nativo do Captain), nunca o que o modelo disse.
  def post_handoff_message!
    content = assistant.config['handoff_message'].presence ||
              I18n.with_locale(account.locale) { I18n.t('conversations.captain.handoff') }
    conversation.messages.create!(
      message_type: :outgoing, account_id: account.id, inbox_id: conversation.inbox_id,
      sender: assistant, content: content,
      # Preserva o `waiting_since` que `bot_handoff!` ja definiu (ou vai
      # definir logo em seguida) - a mesma preocupacao do job nativo do
      # Captain ao criar a mensagem de encaminhamento.
      preserve_waiting_since: true
    )
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
    post_handoff_message!
    conversation.bot_handoff!(dispatch_event: false) unless handed_off_by_captain?
    pre_existing = run.ticket.present?
    ticket = build_and_link_ticket!
    return handoff(result: { turns: turns_used, ticket_error: ticket[:error] }) if ticket.is_a?(Hash)

    ticket.update!(priority: level_priority)
    # Sem isso a conversa ficava so "encaminhada" (bot solto), sem Mesa, Fila
    # nem prioridade nenhuma - so o `ai_triage` (nivel 3-5) fazia esse
    # roteamento; a IA que tenta resolver (nivel 1-2) e nao consegue precisa
    # do mesmo tratamento quando desiste.
    route_conversation_to_humans!(team_id: params[:team_id], priority: level_priority, queue_id: default_queue_id)
    post_ticket_reference!(ticket, pre_existing: pre_existing)
    handoff(result: { turns: turns_used })
  end

  # "Depois informar o numero do ticket criado" - uma segunda mensagem, so
  # depois que o ticket (novo ou ja existente) e conhecido, nunca inventada
  # antes disso.
  def post_ticket_reference!(ticket, pre_existing:)
    key = pre_existing ? 'automations.flow.ticket_reference.existing' : 'automations.flow.ticket_reference.created'
    conversation.messages.create!(
      message_type: :outgoing, account_id: account.id, inbox_id: conversation.inbox_id,
      sender: assistant, content: I18n.t(key, numero: ticket.display_id),
      preserve_waiting_since: true
    )
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
