# Confere se a descricao que o cliente deu do problema (`resposta.problema`)
# tem informacao suficiente pra classificar - "preciso de ajuda" ou so o nome
# de um modulo nao da. Quando nao da, segue pelo branch `unclear` (uma
# pergunta de esclarecimento) - nunca mais que uma vez, quem monta o fluxo e
# quem decide pra onde a etapa seguinte aponta depois.
#
# Falha da IA nunca trava o fluxo: sem resposta clara dela, assume que esta
# claro o bastante e segue (a classificacao de prioridade depois tem sua
# propria rede de seguranca).
class AutomationRules::Flow::Steps::CheckProblemClarity < AutomationRules::Flow::Steps::Base
  TRANSCRIPT_MESSAGE_LIMIT = 20

  def perform
    return continue if clear_enough?

    branch_unclear
  end

  private

  def clear_enough?
    classification = Captain::Llm::ProblemClarityClassifierService.new(conversation: conversation).classify(transcript: transcript)
    classification['claro'] != false
  end

  def branch_unclear
    target = step.dig('branches', 'unclear')
    return continue if target.blank?

    continue(target, result: { claro: false })
  end

  def transcript
    conversation.messages
                .where(message_type: %i[incoming outgoing], private: false)
                .order(:created_at).last(TRANSCRIPT_MESSAGE_LIMIT)
                .map { |message| "#{message.incoming? ? 'Cliente' : 'Atendimento'}: #{message.content}" }
                .join("\n")
  end
end
