# Uma unica chamada estruturada ao LLM - nao um agente com ferramentas - para
# classificar urgencia/impacto de um atendimento, de qualquer nivel de
# cliente. So interpreta; quem decide a prioridade final e o
# `Tickets::HelpdeskPriority`, com base nesta classificacao mais o nivel do
# cliente (a IA nunca define prioridade sozinha, so descreve o problema em
# termos que o backend consegue validar).
class Captain::Llm::UrgencyImpactClassifierService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  LEVELS = %w[baixa media alta].freeze

  # Criterios definidos pela Ingrid (conta DSConnect) - nao inventar novos
  # criterios nem extrapolar alem do que foi combinado com ela.
  SYSTEM_PROMPT = <<~PROMPT.freeze
    Voce e um classificador de triagem de suporte tecnico. A partir da transcricao
    de uma conversa com um cliente, responda SOMENTE com um objeto JSON, sem nenhum
    texto fora dele, no formato:
    {"urgencia": "baixa" | "media" | "alta", "impacto": "baixa" | "media" | "alta",
     "resumo_problema": "resumo objetivo do problema relatado",
     "acao_sugerida": "proximo passo sugerido para quem for atender"}

    "urgencia" e o quao rapido isto precisa ser tratado. "impacto" e o quanto isto
    atrapalha a operacao do cliente. Use estes criterios:

    ALTA (impacto e/ou urgencia): o sistema esta fora do ar ou travado para todo
    mundo na empresa; ou existe um ERRO financeiro real (cobranca errada,
    cobranca duplicada, pagamento nao reconhecido, qualquer perda de dinheiro).
    Um pedido de rotina que envolve dinheiro sem nenhum erro - por exemplo,
    pedir para emitir uma nota fiscal, gerar um boleto ou tirar duvida sobre
    cobranca - NAO conta como alta so por mencionar dinheiro; so conta se algo
    saiu errado.

    BAIXA: duvida de como usar alguma funcao ou pedido de rotina (o cliente nao
    relata nenhum erro, so quer que algo seja feito ou nao sabe fazer algo -
    isto inclui pedir para emitir nota fiscal, gerar boleto, etc.); sugestao ou
    pedido de melhoria (nao e um problema real); afeta so uma pessoa e ela
    consegue continuar trabalhando de outro jeito; nada no texto sugere pressa
    ou prazo.

    MEDIA: qualquer coisa que nao se encaixa claramente em alta ou baixa - por
    exemplo, um erro real que atrapalha o trabalho mas tem contorno, ou que afeta
    um grupo de pessoas sem travar a empresa inteira, sem envolver dinheiro e sem
    parar tudo.

    O nivel do cliente ja e considerado separadamente pelo sistema depois desta
    classificacao - nao tente adivinhar ou usar isso aqui, julgue so pelo que a
    conversa realmente diz sobre o problema. Nunca invente informacao que a
    conversa nao deu.
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
