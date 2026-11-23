# Atrasa o ENVIO de uma mensagem de automacao (`AutomationRules::ActionService#send_message`)
# por alguns segundos - chamado com `set(wait: ...)`, nunca direto.
#
# O motivo e' puramente de entrega em tempo real: a automacao roda no mesmo
# instante em que a conversa e' criada (ex.: primeira mensagem do cliente no
# chat do Portal, ou no Website Widget), e o navegador de quem esta do outro
# lado so assina o canal (ActionCable) DEPOIS de receber a resposta daquele
# envio. Sem este atraso, a automacao podia terminar de criar e transmitir a
# mensagem antes da assinatura existir - a mensagem ficava gravada certinho
# no servidor, mas sumia da tela ate um F5.
class AutomationRules::SendMessageJob < ApplicationJob
  queue_as :default

  def perform(rule_id:, conversation_id:, content:)
    rule = AutomationRule.find_by(id: rule_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if rule.blank? || conversation.blank?

    Current.executed_by = rule
    Messages::MessageBuilder.new(
      nil,
      conversation,
      { content: content, private: false, content_attributes: { automation_rule_id: rule.id } }
    ).perform
  ensure
    Current.executed_by = nil
  end
end
