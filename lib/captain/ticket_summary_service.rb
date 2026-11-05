# Resume a(s) Conversa(s) vinculada(s) a um Ticket para virar a descricao
# dele - pedido da Ingrid para facilitar o agente descrever/fechar os
# proprios tickets, mesma ideia do "Resumir Conversa" do chat do atendente
# (ver Captain::SummaryService), mas por Ticket (que pode ter mais de uma
# Conversation vinculada, ver TicketConversation) em vez de por Conversation.
class Captain::TicketSummaryService < Captain::BaseTaskService
  # `additionalProperties: false` e' exigido pela Groq (JSON Schema estrito)
  # para qualquer objeto do schema - a OpenAI aceita sem isso, mas a Groq
  # rejeita a chamada inteira ("invalid JSON schema for response_format").
  SCHEMA = {
    type: 'object',
    properties: {
      title: { type: 'string' },
      description: { type: 'string' }
    },
    required: %w[title description],
    additionalProperties: false
  }.freeze

  pattr_initialize [:account!, :ticket!]

  def perform
    return { error: I18n.t('captain.ticket_summary.no_conversation') } if transcript.blank?

    response = make_api_call(
      feature: 'editor',
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: transcript }
      ],
      schema: SCHEMA
    )
    return response if response[:error]

    parse(response[:message])
  end

  private

  # `chat.with_schema` pode devolver o conteudo ja como Hash (saida
  # estruturada) ou como uma string JSON, dependendo do provider por baixo -
  # os dois casos sao tratados aqui (mesmo padrao de Captain::TicketDraftService).
  def parse(message)
    data = message.is_a?(String) ? JSON.parse(message) : message
    data = data.with_indifferent_access

    {
      title: data[:title].to_s.strip.presence,
      message: data[:description].to_s.strip.presence
    }
  rescue JSON::ParserError, TypeError, NoMethodError
    { error: 'invalid_ai_response' }
  end

  def transcript
    @transcript ||= ticket.conversations
                          .order(:created_at)
                          .map { |conversation| conversation.to_llm_text(include_contact_details: false) }
                          .reject(&:blank?)
                          .join("\n\n---\n\n")
  end

  def system_prompt
    <<~PROMPT
      #{prompt_from_file('ticket_summary')}

      Reply in #{account.locale_english_name}.
    PROMPT
  end

  def event_name
    'ticket_summary'
  end

  def use_account_openai_hook?
    true
  end
end
