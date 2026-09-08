# Encerra as triagens que ficaram esperando resposta alem do prazo.
#
# Sem isto, um cliente que abandona a conversa no meio deixa a execucao viva
# para sempre: o bot fica parado esperando, e a proxima mensagem dele - dias
# depois, sobre outro assunto - seria lida como a resposta que faltava.
class AutomationRules::ExpireFlowRunsJob < ApplicationJob
  queue_as :low

  def perform
    AutomationRules::Flow::DispatcherService.expire_stale
  end
end
