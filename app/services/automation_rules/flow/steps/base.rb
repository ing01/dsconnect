# O contrato de uma etapa do fluxo.
#
# Cada tipo de etapa e uma classe pequena que sabe fazer uma coisa e responde
# para onde ir depois. Acrescentar um tipo novo e criar uma classe e registra-la
# no REGISTRY do runner - nada mais no sistema precisa mudar.
#
# O retorno diz ao runner o que fazer em seguida:
#   continue(next_id) - segue para a proxima etapa na mesma passada
#   wait(next_id)     - para aqui e espera a resposta do cliente
#   stop              - fluxo termina
#   handoff           - fluxo termina e o atendimento fica para uma pessoa
class AutomationRules::Flow::Steps::Base
  Result = Struct.new(:action, :next_step_id, :result, :error, keyword_init: true)

  def initialize(run:, step:, resolver:, message: nil)
    @run = run
    @step = step
    @resolver = resolver
    @message = message
  end

  def perform
    raise NotImplementedError
  end

  private

  attr_reader :run, :step, :resolver, :message

  def params
    @params ||= (step['params'] || {}).with_indifferent_access
  end

  def conversation
    run.conversation
  end

  def account
    run.account
  end

  # O texto configurado, ja com as variaveis trocadas.
  def rendered(key)
    resolver.render(params[key])
  end

  def continue(next_id = step['next'], result: {})
    Result.new(action: :continue, next_step_id: next_id, result: result)
  end

  def wait(next_id = step['next'], result: {})
    Result.new(action: :wait, next_step_id: next_id, result: result)
  end

  def stop(result: {})
    Result.new(action: :stop, result: result)
  end

  def handoff(result: {})
    Result.new(action: :handoff, result: result)
  end

  def fail_step(error)
    Result.new(action: :fail, error: error)
  end

  # Mensagem do bot para o cliente. Sai como uma mensagem comum da conversa,
  # entao aparece no historico e no widget como qualquer outra.
  def say(content)
    return if content.blank?

    Messages::MessageBuilder.new(
      nil, conversation,
      { content: content, private: false,
        content_attributes: { automation_rule_id: run.automation_rule_id } }
    ).perform
  end
end
