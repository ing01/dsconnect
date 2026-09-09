# Uma unica chamada estruturada ao LLM - nao um agente com ferramentas - para
# classificar urgencia/impacto de um atendimento de nivel 3-5. So interpreta;
# quem decide a prioridade final e o `Tickets::HelpdeskPriority`, com base
# nesta classificacao mais o nivel do cliente (a IA nunca define prioridade
# sozinha, so descreve o problema em termos que o backend consegue validar).
class Captain::Llm::UrgencyImpactClassifierService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  LEVELS = %w[baixa media alta].freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Voce e um classificador de triagem de suporte tecnico. A partir da transcricao
    de uma conversa com um cliente, responda SOMENTE com um objeto JSON, sem nenhum
    texto fora dele, no formato:
    {"urgencia": "baixa" | "media" | "alta", "impacto": "baixa" | "media" | "alta",
     "resumo_problema": "resumo objetivo do problema relatado",
     "acao_sugerida": "proximo passo sugerido para quem for atender"}
    "urgencia" e o quao rapido isto precisa ser tratado. "impacto" e o quanto isto
    atrapalha a operacao do cliente. Nunca invente informacao que a conversa nao deu.
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

  # Nunca confia no texto livre: so aceita a resposta se os dois campos
  # batem exatamente com os valores permitidos.
  def normalize(parsed)
    urgencia = parsed['urgencia'].to_s
    impacto = parsed['impacto'].to_s
    return failure('invalid_classifier_response') unless LEVELS.include?(urgencia) && LEVELS.include?(impacto)

    {
      'urgencia' => urgencia,
      'impacto' => impacto,
      'resumo_problema' => parsed['resumo_problema'].to_s.presence,
      'acao_sugerida' => parsed['acao_sugerida'].to_s.presence,
      'model' => @model
    }
  end

  def failure(reason)
    { 'urgencia' => nil, 'impacto' => nil, 'resumo_problema' => nil, 'acao_sugerida' => nil,
      'error' => reason, 'model' => @model }
  end

  def instrumentation_params(transcript)
    {
      span_name: 'llm.helpdesk.urgency_impact_classifier',
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
