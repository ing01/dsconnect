# Le um texto livre (ja transcrito, se veio de audio gravado no Portal do
# Cliente) e devolve um RASCUNHO de ticket - categoria, titulo e descricao -
# para o cliente revisar e confirmar. Nunca cria o ticket sozinho: quem grava
# de verdade continua sendo Api::V1::Client::TicketsController#create, sem
# nenhuma mudanca.
#
# `categories` chega ja resolvida pelo controller (todas as Categorias das
# Mesas visiveis no Portal para este cliente) - o cliente nunca escolhe Mesa
# na tela normal de abertura, e a IA nao devia exigir isso so porque existe.
class Captain::TicketDraftService < Captain::BaseTaskService
  SCHEMA = {
    type: 'object',
    properties: {
      ticket_category_id: { type: 'integer' },
      title: { type: 'string' },
      description: { type: 'string' }
    },
    required: %w[ticket_category_id title description]
  }.freeze

  pattr_initialize [:account!, :categories!, :text!]

  def perform
    response = make_api_call(messages: messages, model: GPT_MODEL, schema: SCHEMA)
    return response if response[:error]

    parse(response[:message])
  end

  private

  def event_name
    'ticket_draft'
  end

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: text }
    ]
  end

  def system_prompt
    <<~PROMPT
      Voce ajuda um cliente a abrir um chamado de suporte a partir do que ele
      escreveu ou falou. Categorias disponiveis (use so o id de uma delas em
      ticket_category_id, a que melhor descrever o problema):
      #{categories.map { |category| "#{category.id}: #{category.name}" }.join("\n")}

      Responda em portugues, com um titulo curto (ate 80 caracteres) e uma
      descricao clara do problema relatado, prontos para o cliente revisar
      antes de confirmar a abertura.
    PROMPT
  end

  # `chat.with_schema` pode devolver o conteudo ja como Hash (saida
  # estruturada) ou como uma string JSON, dependendo do provider por baixo -
  # os dois casos sao tratados aqui.
  def parse(message)
    data = message.is_a?(String) ? JSON.parse(message) : message
    data = data.with_indifferent_access

    category = categories.find { |candidate| candidate.id == data[:ticket_category_id].to_i }
    {
      ticket_category_id: category&.id,
      title: data[:title].to_s.strip.presence,
      description: data[:description].to_s.strip.presence
    }
  rescue JSON::ParserError, TypeError, NoMethodError
    { error: 'invalid_ai_response' }
  end
end
