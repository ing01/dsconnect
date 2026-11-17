# Consulta pontual ao DueRules (regras de negocio do ERP da Duesoft) durante a
# triagem, so para a Dua entender melhor o termo/tela que o cliente descreveu -
# nunca para tentar resolver o problema. Usa o perfil "atendimento", pensado
# para expor ao cliente, nunca o de suporte/implantacao.
class Captain::Tools::DuerulesLookupTool < Captain::Tools::BasePublicTool
  description 'Look up how a system screen, routine or term works in the Duesoft business rules base (DueRules), ' \
              'to better understand what the customer is describing before classifying the ticket. ' \
              'Use it only to understand the system, never to try to solve the problem for the customer.'
  param :question, type: 'string', desc: 'The question or subject, in natural language (Portuguese)', required: true

  def active?
    duerules_client.configured?
  end

  def perform(tool_context, question:)
    return 'DueRules is not configured' unless duerules_client.configured?

    conversation = find_conversation(tool_context.state)
    log_tool_usage('duerules_lookup', conversation_id: conversation&.id, question: question)

    duerules_client.call_tool('buscar_regras', pergunta: question, limite: 3)
  rescue Duerules::Client::Error => e
    Rails.logger.warn "[DueRules] triage lookup: #{e.message}"
    "A base de regras DueRules nao respondeu agora (#{e.message})."
  end

  private

  def duerules_client
    @duerules_client ||= Duerules::Client.new(profile: :atendimento)
  end

  def permissions
    []
  end
end
