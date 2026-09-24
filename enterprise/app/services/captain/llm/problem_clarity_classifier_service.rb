# Antes de classificar a prioridade, confere se o cliente de fato descreveu
# o problema - "preciso de ajuda" ou so o nome de um modulo (financeiro,
# estoque) nao da pra entender do que se trata. Uma unica chamada, so
# verdadeiro/falso - quem decide o que fazer com isso e a etapa do fluxo.
class Captain::Llm::ProblemClarityClassifierService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Voce avalia se a descricao de um cliente de suporte tecnico tem informacao
    suficiente pra entender do que se trata - nao para resolver, so pra saber
    o que esta acontecendo. Responda SOMENTE com um objeto JSON, sem nenhum
    texto fora dele, no formato: {"claro": true | false}.

    NAO e suficiente (responda false): pedidos genericos como "preciso de
    ajuda", "tenho um problema", "preciso de suporte"; so o nome de um modulo
    ou area sem dizer o que esta acontecendo (ex: "financeiro", "estoque",
    "vendas"); mensagens vagas sem nenhum detalhe do que aconteceu.

    E suficiente (responda true): qualquer descricao que diga o que esta
    acontecendo, mesmo curta (ex: "sistema caiu", "nao consigo emitir nota
    fiscal", "relatorio de vendas nao abre").
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
    { 'claro' => nil, 'error' => e.message }
  end

  private

  def parse_response(content)
    return {} if content.blank?

    JSON.parse(sanitize_json_response(content))
  rescue JSON::ParserError
    {}
  end

  # So aceita true/false de verdade - qualquer outra coisa (campo ausente,
  # tipo errado) vira `nil`, tratado como "sem informacao" por quem chama.
  def normalize(parsed)
    return { 'claro' => nil } unless [true, false].include?(parsed['claro'])

    { 'claro' => parsed['claro'] }
  end

  def instrumentation_params(transcript)
    {
      span_name: 'llm.helpdesk.problem_clarity_classifier',
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
