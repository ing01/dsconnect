# Uma unica chamada estruturada ao LLM - nao um agente com ferramentas - para
# classificar a prioridade de um atendimento, de qualquer nivel de cliente.
# So interpreta; quem decide a prioridade final e o `Tickets::HelpdeskPriority`,
# com base nesta classificacao mais o nivel do cliente (a IA nunca define
# prioridade sozinha, so descreve o problema em termos que o backend consegue
# validar).
class Captain::Llm::TriagePriorityClassifierService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  LEVELS = %w[baixa media alta].freeze

  # Criterios definidos pela Ingrid (conta DSConnect) - nao inventar novos
  # criterios nem extrapolar alem do que foi combinado com ela.
  SYSTEM_PROMPT = <<~PROMPT.freeze
    Voce e um classificador de triagem de suporte tecnico. A partir da transcricao
    de uma conversa com um cliente, responda SOMENTE com um objeto JSON, sem nenhum
    texto fora dele, no formato:
    {"prioridade": "baixa" | "media" | "alta",
     "resumo_problema": "resumo objetivo do problema relatado",
     "acao_sugerida": "proximo passo sugerido para quem for atender"}

    Classifique a prioridade usando estes criterios:

    ALTA: impacto critico na operacao do cliente - sistema completamente parado;
    cliente nao consegue operar; emissao fiscal bloqueada; faturamento impedido;
    problema que impede uma operacao essencial; grande parte da operacao
    comprometida; situacao urgente que exige intervencao rapida.

    MEDIA: problema importante que afeta a operacao, mas sem interrupcao critica
    ou total - uma funcionalidade especifica nao funciona; problema que prejudica
    parte da operacao; erro recorrente mas o cliente ainda consegue trabalhar;
    funcionalidade importante indisponivel, mas existem alternativas.

    BAIXA: sem impacto critico ou imediato na operacao - duvidas; solicitacoes de
    orientacao; configuracoes; pequenas inconsistencias; solicitacoes de melhoria;
    questoes que nao impedem o funcionamento normal do sistema.

    Tente classificar com as informacoes ja fornecidas pelo cliente, sem perguntar
    mais nada e sem inventar informacao que a conversa nao deu. Se a descricao ja
    for clara o suficiente, classifique direto, mesmo que curta.
  PROMPT

  def initialize(conversation:)
    super(feature: 'assistant', account: conversation.account)
    @conversation = conversation
    @temperature = 0.0
  end

  def classify(transcript:)
    response = instrument_llm_call(instrumentation_params(transcript)) do
      chat
        .with_params(response_format: { type: 'json_object' })
        .with_instructions(SYSTEM_PROMPT)
        .ask(transcript)
    end

    normalize(parse_response(response.content))
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @conversation.account).capture_exception
    failure(e.message)
  end

  private

  def parse_response(content)
    return {} if content.blank?

    JSON.parse(sanitize_json_response(content))
  rescue JSON::ParserError
    {}
  end

  # Nunca confia no texto livre: so aceita a resposta se o campo bate
  # exatamente com um dos valores permitidos.
  def normalize(parsed)
    prioridade = parsed['prioridade'].to_s
    return failure('invalid_classifier_response') unless LEVELS.include?(prioridade)

    {
      'prioridade' => prioridade,
      'resumo_problema' => parsed['resumo_problema'].to_s.presence,
      'acao_sugerida' => parsed['acao_sugerida'].to_s.presence,
      'model' => @model
    }
  end

  def failure(reason)
    { 'prioridade' => nil, 'resumo_problema' => nil, 'acao_sugerida' => nil,
      'error' => reason, 'model' => @model }
  end

  def instrumentation_params(transcript)
    {
      span_name: 'llm.helpdesk.triage_priority_classifier',
      model: @model,
      temperature: @temperature,
      account_id: @conversation.account_id,
      conversation_id: @conversation.display_id,
      feature_name: 'helpdesk_triage',
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: transcript }
      ]
    }
  end
end
