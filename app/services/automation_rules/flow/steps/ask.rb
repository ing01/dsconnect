# Pergunta algo e para, esperando a resposta do cliente.
#
# Executada duas vezes: na primeira faz a pergunta e devolve `wait`; quando a
# resposta chega, o runner chama de novo com a mensagem, e ai a etapa valida,
# guarda o valor e segue.
class AutomationRules::Flow::Steps::Ask < AutomationRules::Flow::Steps::Base
  DEFAULT_TIMEOUT_MINUTES = 60

  def perform
    return ask_question if message.blank?

    receive_answer
  end

  # Quantos minutos esperar antes de desistir. Sem isso uma conversa abandonada
  # deixaria a execucao viva para sempre.
  def timeout_minutes
    (params[:timeout_minutes].presence || DEFAULT_TIMEOUT_MINUTES).to_i
  end

  private

  def ask_question
    content = rendered(:content)
    return fail_step(I18n.t('automations.flow.errors.empty_message')) if content.blank?

    say(content)
    # Espera na propria etapa: a resposta volta para ca, e nao para a seguinte.
    wait(step['id'], result: { asked: content })
  end

  def receive_answer
    answer = message.content.to_s.strip
    return retry_answer if answer.blank?

    normalized = normalize(answer)
    return retry_answer(invalid: true) if normalized.nil?

    run.write_variable(save_as, normalized)
    continue(result: { answer: normalized })
  end

  # `save_as` fica sob `resposta.` por convencao, para o admin escrever
  # `{{resposta.nome}}` sem precisar saber como isto e guardado por dentro.
  def save_as
    key = params[:save_as].presence || 'valor'
    key.start_with?('resposta.') ? key : "resposta.#{key}"
  end

  # Uma resposta que nao serve nao derruba o fluxo: o bot explica e pergunta de
  # novo, que e o que uma pessoa faria.
  def retry_answer(invalid: false)
    say(rendered(:retry_message).presence || I18n.t('automations.flow.retry')) if invalid
    wait(step['id'], result: { rejected: true })
  end

  def normalize(answer)
    case params[:answer_type].to_s
    when 'cnpj' then normalize_cnpj(answer)
    else answer
    end
  end

  # So os digitos, e so se o CNPJ for valido de fato - a mesma checagem de
  # digito verificador que a Empresa ja usa, para o fluxo nao aceitar um numero
  # que o cadastro depois recusaria.
  def normalize_cnpj(answer)
    digits = answer.gsub(/\D/, '')
    return nil unless Company.valid_cnpj?(digits)

    digits
  end
end
