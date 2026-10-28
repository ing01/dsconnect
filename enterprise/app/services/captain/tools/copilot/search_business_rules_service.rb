class Captain::Tools::Copilot::SearchBusinessRulesService < Captain::Tools::Copilot::DuerulesBaseTool
  def self.name
    'search_business_rules'
  end
  description 'Search the ERP Duesoft business rules base (DueRules) to answer questions about screens, routines, ' \
              'registers, fiscal behavior and how the system works. Use it for any question about the ERP. ' \
              'Call get_company_profile first, once per conversation.'
  param :question, desc: 'The question or subject, in natural language (Portuguese)', required: true
  param :client, desc: 'Customer name to also bring that customer\'s customizations (use list_rule_clients for the exact name)',
                 required: false
  param :limit, type: :number, desc: 'Maximum number of rules to return, from 1 to 10 (default 5)', required: false

  def execute(question:, client: nil, limit: nil)
    call_duerules('buscar_regras', pergunta: question, cliente: client.presence, limite: limit&.to_i&.clamp(1, 10))
  end
end
