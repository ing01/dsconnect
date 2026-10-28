class Captain::Tools::Copilot::ListRuleClientsService < Captain::Tools::Copilot::DuerulesBaseTool
  def self.name
    'list_rule_clients'
  end
  description 'List the customers known by the business rules base (DueRules), with their former names. ' \
              'Use it to find the exact customer name to pass as "client" to the other business rules tools.'

  def execute
    call_duerules('listar_clientes')
  end
end
