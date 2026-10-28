class Captain::Tools::Copilot::GetCompanyProfileService < Captain::Tools::Copilot::DuerulesBaseTool
  def self.name
    'get_company_profile'
  end
  description 'Get the company profile from the business rules base (DueRules). Without a client it explains what ' \
              'this access can see; with a client it returns that customer\'s operational profile (processes, ' \
              'settings, customizations, integrations). Call it first, once per conversation, before search_business_rules.'
  param :client, desc: 'Customer whose profile to see (use list_rule_clients for the exact name); empty = this access',
                 required: false

  def execute(client: nil)
    call_duerules('perfil_da_empresa', cliente: client.presence)
  end
end
