# A avaliacao mensal de satisfacao do Portal do Cliente.
#
# Uma por contato por mes - a fronteira e SEMPRE o proprio contato (ver a
# migration). Nao e Manifestacao (SAC) nem Ticket: e uma pesquisa periodica,
# independente, sem fluxo de atendimento nenhum por tras.
class MonthlySatisfactionSurvey < ApplicationRecord
  # Opcionais na associacao, exigidos na CRIACAO: excluir uma Empresa ou um
  # Contato nulifica o vinculo em vez de apagar o historico de satisfacao -
  # mesmo acordo que Manifestation tem com os dois.
  belongs_to :account
  belongs_to :company, optional: true
  belongs_to :contact, optional: true

  has_many :answers, class_name: 'MonthlySatisfactionSurveyAnswer', dependent: :destroy, inverse_of: :monthly_satisfaction_survey

  # As dez perguntas fixas, NA ORDEM em que aparecem na tela. Uma chave
  # estavel por pergunta - o TEXTO mora so no i18n do frontend
  # (`MONTHLY_SURVEY.QUESTIONS.<chave>`), nunca aqui: e o que permite reescrever
  # a redacao de uma pergunta sem tocar em nenhuma resposta ja gravada.
  #
  # Fixo no codigo de proposito, e nao numa tabela configuravel: o pedido e
  # manter o questionario simples, e uma tela de administracao de perguntas
  # seria complexidade que ninguem pediu ainda.
  QUESTION_KEYS = %w[
    erp_overall
    erp_meets_needs
    erp_ease_of_use
    erp_practicality
    erp_performance
    support_service
    support_clarity
    support_response_time
    product_evolution
    overall_experience
  ].freeze

  validates :reference_month, presence: true
  validates :contact_id, presence: true, on: :create

  # SEM validacao de unicidade aqui de proposito: ela faria um SELECT antes do
  # INSERT (racy - duas abas do Portal enviando ao mesmo tempo passariam as
  # duas), e so' daria uma falsa sensacao de seguranca. A trava de verdade e o
  # INDICE UNICO da migration; `SubmitService` e quem traduz a recusa dele
  # (`ActiveRecord::RecordNotUnique`) num erro legivel.

  before_validation :ensure_account_id
  before_validation :normalize_reference_month

  scope :for_month, ->(month) { where(reference_month: month) }
  scope :ordered, -> { order(reference_month: :desc, id: :desc) }

  # O mes que vale "agora" para toda a feature - uma definicao so, usada pela
  # leitura (o cliente ja respondeu o mes corrente?) e pela gravacao (a
  # resposta vale para QUE mes?). Sempre o dia 1: e o que faz o indice unico
  # da migration enxergar "o mesmo mes" independente do dia em que a pessoa
  # responde.
  def self.current_reference_month
    Date.current.beginning_of_month
  end

  def self.answered_for?(contact:, month: current_reference_month)
    return false if contact.blank?

    contact.monthly_satisfaction_surveys.exists?(reference_month: month)
  end

  # Media por pergunta, pronta para a area interna comparar perguntas entre
  # si e mes a mes - e o ponto que o pedido deixa explicito para o futuro.
  def self.average_by_question(scope: all)
    MonthlySatisfactionSurveyAnswer.where(monthly_satisfaction_survey_id: scope.select(:id))
                                   .group(:question_key)
                                   .average(:rating)
  end

  def average_rating
    answers.average(:rating)
  end

  private

  def ensure_account_id
    self.account_id ||= company&.account_id || contact&.account_id
  end

  def normalize_reference_month
    self.reference_month = reference_month.beginning_of_month if reference_month.present?
  end
end
