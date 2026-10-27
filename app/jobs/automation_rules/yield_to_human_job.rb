# Encerra a triagem quando um atendente responde ao cliente (ver
# AutomationRules::Flow::DispatcherService.yield_to_human).
#
# Em job proprio porque precisa esperar a passada em andamento terminar - e essa
# espera nao pode acontecer dentro do job de eventos da mensagem do atendente.
class AutomationRules::YieldToHumanJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.blank?

    AutomationRules::Flow::DispatcherService.hand_off_to_human(message: message)
  end
end
