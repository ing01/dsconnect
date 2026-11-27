# Escreve o "Resumo do cliente" que o atendente le antes de atender. Recebe o
# material pronto (ver CustomerBriefing::MaterialBuilder) e devolve o texto em
# campos fixos.
class Captain::CustomerBriefingService < Captain::BaseTaskService
  LIST_FIELDS = %w[recent_topics pending_items attention_points].freeze
  ITEMS_LIMIT = 6

  # `additionalProperties: false` e todos os campos em `required`: exigencia da
  # Groq (ver Captain::TicketSummaryService).
  SCHEMA = {
    type: 'object',
    properties: {
      overview: { type: 'string' },
      recent_topics: { type: 'array', items: { type: 'string' } },
      pending_items: { type: 'array', items: { type: 'string' } },
      attention_points: { type: 'array', items: { type: 'string' } }
    },
    required: ['overview', *LIST_FIELDS],
    additionalProperties: false
  }.freeze

  pattr_initialize [:account!, :material!]

  def perform
    response = make_api_call(
      feature: 'editor',
      messages: [
        { role: 'system', content: prompt_from_file('customer_briefing') },
        { role: 'user', content: material }
      ],
      schema: SCHEMA
    )
    return response if response[:error]

    content = parse(response[:message])
    content ? { message: content } : { error: 'invalid_ai_response' }
  end

  private

  # A resposta pode vir como Hash (saida estruturada) ou como texto JSON,
  # conforme o provedor. Nil quando nao da para aproveitar.
  def parse(message)
    data = message.is_a?(String) ? JSON.parse(message[/\{.*\}/m].to_s) : message
    data = data.to_h.stringify_keys
    content = LIST_FIELDS.index_with { |field| clean_list(data[field]) }
    content = { 'overview' => data['overview'].to_s.strip }.merge(content)
    content if content.values.any?(&:present?)
  rescue JSON::ParserError, TypeError, NoMethodError
    nil
  end

  def clean_list(value)
    Array(value).grep(String).map(&:strip).compact_blank.first(ITEMS_LIMIT)
  end

  def event_name
    'customer_briefing'
  end

  def use_account_openai_hook?
    true
  end
end
