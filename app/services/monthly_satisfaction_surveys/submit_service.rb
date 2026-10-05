# Grava a avaliacao mensal de um contato: a avaliacao em si mais as dez
# respostas, numa transacao so.
#
# A TRAVA de "uma por mes" e' o INDICE UNICO da migration
# (`index_monthly_surveys_unique_per_contact_month`) - este servico nao
# reimplementa essa regra com um `exists?` antes de criar, porque isso teria
# uma janela de corrida (duas abas do Portal enviando ao mesmo tempo). Deixa o
# banco recusar, e traduz a recusa (`ActiveRecord::RecordNotUnique`) num erro
# que o controller sabe responder.
class MonthlySatisfactionSurveys::SubmitService
  class AlreadyAnswered < StandardError; end
  class InvalidAnswers < StandardError; end

  pattr_initialize [:contact!, :answers!, :comment]

  def perform
    validar_perguntas!

    # `requires_new: true` para sempre abrir um SAVEPOINT proprio - se o
    # chamador (um controller, um teste) ja estiver dentro de outra
    # transacao, uma recusa aqui nao pode deixar a transacao de FORA
    # inutilizada para o resto da requisicao.
    ActiveRecord::Base.transaction(requires_new: true) do
      survey = build_survey
      survey.save!
      criar_respostas!(survey)
      survey
    end
  rescue ActiveRecord::RecordNotUnique
    raise AlreadyAnswered, I18n.t('monthly_satisfaction_survey.already_answered')
  end

  private

  attr_reader :contact, :answers, :comment

  def account
    contact.account
  end

  # Todas as DEZ perguntas, com nota de 1 a 5 - nenhuma de menos, nenhuma
  # estranha. A pergunta aberta (`comment`) fica de fora desta checagem: ela e
  # OPCIONAL, por pedido.
  def validar_perguntas!
    chaves_recebidas = answers.keys.map(&:to_s)
    faltando = MonthlySatisfactionSurvey::QUESTION_KEYS - chaves_recebidas
    sobrando = chaves_recebidas - MonthlySatisfactionSurvey::QUESTION_KEYS

    raise InvalidAnswers, I18n.t('monthly_satisfaction_survey.missing_questions', questions: faltando.join(', ')) if faltando.any?
    raise InvalidAnswers, I18n.t('monthly_satisfaction_survey.unknown_question') if sobrando.any?

    return if answers.values.all? { |nota| nota.to_i.between?(1, 5) }

    raise InvalidAnswers, I18n.t('monthly_satisfaction_survey.invalid_rating')
  end

  def build_survey
    account.monthly_satisfaction_surveys.new(
      company_id: contact.client_company_ids.first,
      contact_id: contact.id,
      reference_month: MonthlySatisfactionSurvey.current_reference_month,
      comment: comment.to_s.strip.presence
    )
  end

  def criar_respostas!(survey)
    answers.each do |chave, nota|
      survey.answers.create!(question_key: chave.to_s, rating: nota.to_i)
    end
  end
end
