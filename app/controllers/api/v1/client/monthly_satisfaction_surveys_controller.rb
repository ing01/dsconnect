# A avaliacao mensal de satisfacao, na Area do Cliente.
#
# Recurso SINGULAR de proposito: do ponto de vista do contato so existe "a
# avaliacao DESTE MES", nunca uma lista com id para escolher - ele nao tem
# como ver a de um mes passado nem a de outro contato.
#
# `show` responde "ja respondi este mes?" mais as PERGUNTAS (so as chaves - o
# texto mora no i18n do frontend, nunca aqui: e por isso que trocar a redacao
# de uma pergunta nunca precisa de deploy no backend). `create` grava a
# resposta - e e' o SERVIDOR quem recusa a segunda tentativa
# (`SubmitService`/indice unico), nao a tela.
class Api::V1::Client::MonthlySatisfactionSurveysController < Api::V1::Client::BaseController
  def show
    render json: {
      answered: ja_respondida?,
      reference_month: mes_atual.iso8601,
      question_keys: MonthlySatisfactionSurvey::QUESTION_KEYS
    }
  end

  def create
    survey = MonthlySatisfactionSurveys::SubmitService.new(
      contact: current_contact,
      answers: params_respostas,
      comment: params[:comment]
    ).perform

    render json: { answered: true, reference_month: survey.reference_month.iso8601 }, status: :created
  rescue MonthlySatisfactionSurveys::SubmitService::AlreadyAnswered => e
    render json: { error: e.message, code: 'already_answered' }, status: :unprocessable_entity
  rescue MonthlySatisfactionSurveys::SubmitService::InvalidAnswers => e
    render json: { error: e.message, code: 'invalid_answers' }, status: :unprocessable_entity
  end

  private

  def mes_atual
    MonthlySatisfactionSurvey.current_reference_month
  end

  def ja_respondida?
    MonthlySatisfactionSurvey.answered_for?(contact: current_contact, month: mes_atual)
  end

  # `permit` com a lista FECHADA de chaves validas - nenhuma pergunta
  # inventada passa daqui para o servico, mesmo que o pedido mande uma.
  # `to_h` devolve um Hash de verdade: o servico so sabe iterar Hash, nao
  # ActionController::Parameters.
  def params_respostas
    params.require(:answers).permit(*MonthlySatisfactionSurvey::QUESTION_KEYS).to_h
  end
end
