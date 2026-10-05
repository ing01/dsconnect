# A avaliacao mensal, do lado interno. So LEITURA nesta etapa - quem grava e
# o Portal, pelo contato.
#
# Entregue AGORA, mesmo sem uma tela de dashboard dedicada ainda: e' a
# "estrutura necessaria para armazenar e consultar" que o pedido pede para
# ja' existir, enquanto a tela propria (media por empresa, evolucao mensal em
# grafico etc.) e' trabalho FUTURO. Os agregados que `meta` devolve sao a base
# dela - computados aqui, no servidor, para a tela futura nao precisar somar
# centenas de linhas no navegador.
class Api::V1::Accounts::MonthlySatisfactionSurveysController < Api::V1::Accounts::BaseController
  INCLUDES = [:company, :contact, :answers].freeze

  before_action :fetch_survey, only: [:show]
  before_action :check_authorization

  def index
    @surveys = filtered_scope.includes(*INCLUDES).ordered
    @meta = {
      count: @surveys.size,
      average_rating: MonthlySatisfactionSurveyAnswer.where(monthly_satisfaction_survey_id: @surveys.select(:id)).average(:rating),
      average_by_question: MonthlySatisfactionSurvey.average_by_question(scope: @surveys)
    }
  end

  def show; end

  private

  def filtered_scope
    escopo = Current.account.monthly_satisfaction_surveys
    escopo = escopo.where(company_id: params[:company_id]) if params[:company_id].present?
    escopo = escopo.where(reference_month: params[:reference_month]) if params[:reference_month].present?
    escopo
  end

  def fetch_survey
    @survey = Current.account.monthly_satisfaction_surveys.includes(*INCLUDES).find(params[:id])
  end

  def check_authorization(model = nil)
    super(model || @survey || MonthlySatisfactionSurvey)
  end
end
