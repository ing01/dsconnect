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
    response = generate_response_safely
    @last_response = response
    return finish_by_handoff if response.nil?

    return finish_by_resolution if conversation.resolved?
    return finish_by_handoff if handoff_signaled?(response)

    # Rede de seguranca final: se por qualquer outro motivo nao reconhecido
    # aqui a resposta nao tiver nenhum texto de verdade para o cliente,
    # encaminha em vez de esperar por uma resposta que a IA nunca vai mandar.
    return finish_by_handoff unless post_ai_reply!(response)

    wait(step['id'], result: { turn: turns_used })
  end

  private

  # O agente sinaliza handoff de tres formas possiveis - a mesma checagem que
  # o job nativo do Captain usa (`Captain::Conversation::ResponseBuilderJob#process_response`,
  # `v2_handoff_tool_fired?` / `v2_handoff_tool_completed?` / `legacy_v1_handoff_token?`):
  # a `HandoffTool` foi CHAMADA durante o turno (`handoff_tool_called` na
  # resposta), o handoff foi COMPLETADO (`runner.handoff_completed?`), ou a
  # resposta e' o token interno `"conversation_handoff"` (usado quando a IA
  # decide encaminhar sem passar pela ferramenta, e tambem por
  # `AgentRunResponse#error_response` quando `generate_response` capturou um
  # erro internamente, sem levantar excecao nenhuma).
  #
  # So verificar `handoff_completed?` (como esta etapa fazia antes) deixava os
  # outros dois casos passarem batido: a etapa tentava publicar a resposta do
  # turno de handoff como se fosse uma reply normal - texto vazio ou so o
  # token literal - e ficava esperando a proxima mensagem do cliente para
  # sempre, porque a IA ja tinha decidido encerrar e nunca ia responder de
  # novo. Foi exatamente o "responde 'nao' sobre o ticket e a IA para de
  # responder" relatado, confirmado pelo painel de diagnostico (run parado em
  # `ai_resolve`, status `waiting`, sem nenhum erro registrado).
  def handoff_signaled?(response)
    response['handoff_tool_called'] || runner.handoff_completed? || response['response'] == 'conversation_handoff'
  end

  # `Captain::Llm::TriagePriorityClassifierService` (usada pela triagem) ja
  # guarda contra falha do LLM sozinha, devolvendo um Hash de
  # erro em vez de estourar. `AgentRunnerService#generate_response` (usada
  # aqui, nivel 1-2) nao tem essa protecao - sem este rescue, qualquer erro do
  # provedor (timeout, chave invalida, resposta malformada) subia ate o
  # `rescue` generico do `RunnerService`, que marca a execucao como falha SEM
  # avisar o cliente. A conversa ficava muda para sempre, exatamente o
  # relatado com um cliente de nivel 1.
  def generate_response_safely
    runner.generate_response(message_history: message_history)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    nil
  end

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
    return false if response.blank?

    response_parts = Captain::Assistant::ResponseParts.from_response(response)
    content = response_parts.customer_message_content(citation_urls: assistant.trusted_citation_urls(runner.last_run_result))
    return false if content.blank?

    conversation.messages.create!(
      message_type: :outgoing, account_id: account.id, inbox_id: conversation.inbox_id,
      sender: assistant, content: content,
      additional_attributes: { agent_name: response['agent_name'] }.compact
    )
    account.increment_response_usage
    true
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
    return handoff(result: handoff_diagnostics.merge(ticket_error: ticket[:error])) if ticket.is_a?(Hash)

    ticket.update!(priority: level_priority)
    # Sem isso a conversa ficava so "encaminhada" (bot solto), sem Mesa, Fila
    # nem prioridade nenhuma - so o `ai_triage` (nivel 3-5) fazia esse
    # roteamento; a IA que tenta resolver (nivel 1-2) e nao consegue precisa
    # do mesmo tratamento quando desiste.
    route_conversation_to_humans!(team_id: params[:team_id], priority: level_priority, queue_id: queue_id_for(level_priority))
    post_ticket_reference!(ticket, pre_existing: pre_existing)
    handoff(result: handoff_diagnostics)
  end

  # Sem isso o painel de diagnostico so mostrava "handed_off", nunca o motivo
  # real - se a IA chamou a ferramenta de handoff, se completou, e o que ela
  # de fato respondeu/raciocinou antes de desistir. `@last_response` fica em
  # branco quando o motivo foi outro (assistente mal configurado, turnos
  # esgotados) - por isso tudo aqui e opcional (`&.`).
  def handoff_diagnostics
    {
      turns: turns_used,
      handoff_tool_called: @last_response&.dig('handoff_tool_called'),
      handoff_completed: runner.handoff_completed?,
      ai_response: @last_response&.dig('response'),
      ai_reasoning: @last_response&.dig('reasoning'),
      # Quando `ai_response`/`ai_reasoning` saem em branco com reasoning
      # generico ("Processed by agent"), e porque `process_agent_result`
      # (enterprise/app/services/captain/assistant/agent_run_response.rb)
      # recebeu um `model_output` que nao e' um Hash - o dado bruto por tras
      # disso so aparecia no log do servidor (`Rails.logger.info "[Captain V2]
      # Agent result: ..."`), inacessivel para quem nao tem SSH. Expor aqui
      # evita depender do log do servidor para diagnosticar esse caso.
      raw_agent_output: runner.last_run_result&.output.inspect&.truncate(500),
      # A gem `Agents::Runner` (ai-agents) engole exceoes internamente durante
      # o loop do agente - em vez de deixar subir (o que o `rescue` de
      # `AgentRunnerService#generate_response` pegaria e vira `error_response`,
      # com reasoning "Error occurred: ..."), ela devolve um `RunResult` normal
      # com `output: nil` e o detalhe do erro dentro de `result.error`
      # (`lib/agents/runner.rb#finalize_run`, gem `ai-agents`). Sem isso, um
      # erro de verdade (chamada ao LLM falhando, tool quebrando, etc.) virava
      # um "Processed by agent" generico e indistinguivel de "a IA so nao
      # respondeu nada".
      agent_run_error: runner.last_run_result&.error&.message,
      agent_run_error_class: runner.last_run_result&.error&.class&.name,
      # Lendo o codigo da gem (github.com/chatwoot/ai-agents, lib/agents/runner.rb):
      # o UNICO jeito de "output" sair nil SEM nenhum "error" e' o caminho de
      # sucesso normal (linha ~201, `output: response.content`) quando a
      # resposta da LLM em si vem sem texto e sem chamar nenhuma tool - nao e'
      # uma excecao sendo engolida, e' a IA "respondendo" vazio mesmo. Isso so
      # acontece depois de um handoff interno pra outro agente (`current_agent`
      # muda) ou quando o modelo simplesmente devolve conteudo vazio. Exibe os
      # dois pra distinguir os casos sem precisar do log do servidor.
      current_agent: runner.last_run_result&.context&.dig(:current_agent),
      last_message: runner.last_run_result&.messages&.last&.inspect&.truncate(500)
    }.compact
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
