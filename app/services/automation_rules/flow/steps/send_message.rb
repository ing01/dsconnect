# Manda uma mensagem e segue em frente, sem esperar resposta.
class AutomationRules::Flow::Steps::SendMessage < AutomationRules::Flow::Steps::Base
  def perform
    content = rendered(:content)
    return fail_step(I18n.t('automations.flow.errors.empty_message')) if content.blank?

    say(content)
    continue(result: { content: content })
  end
end
