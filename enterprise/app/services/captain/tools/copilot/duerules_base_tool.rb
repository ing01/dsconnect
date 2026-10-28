# Base das ferramentas do Copiloto que consultam o DueRules (a base de regras do
# ERP da Duesoft). Concentra o que e' comum: so' aparecem quando o DueRules esta
# configurado, so' para quem atende (mesma permissao de ver conversas), e um erro
# de rede vira uma frase que o Copiloto repassa ao atendente em vez de quebrar a
# conversa.
class Captain::Tools::Copilot::DuerulesBaseTool < Captain::Tools::BaseTool
  def active?
    Duerules::Client.configured? && (
      user_has_permission('conversation_manage') ||
      user_has_permission('conversation_unassigned_manage') ||
      user_has_permission('conversation_participating_manage')
    )
  end

  private

  def call_duerules(tool, arguments = {})
    Duerules::Client.new.call_tool(tool, arguments)
  rescue Duerules::Client::Error => e
    Rails.logger.warn "[DueRules] #{tool}: #{e.message}"
    "A base de regras DueRules nao respondeu agora (#{e.message}). Diga isso ao atendente e nao invente a regra."
  end
end
