# Uma resposta, de uma pergunta, de uma avaliacao mensal.
#
# Linha por pergunta, e nao um JSONB na avaliacao: e o que deixa "media por
# pergunta" e "evolucao mensal por pergunta" uma consulta de GROUP BY direta
# (ver `MonthlySatisfactionSurvey.average_by_question`), sem espalhar logica
# de agregacao de JSONB pela aplicacao.
class MonthlySatisfactionSurveyAnswer < ApplicationRecord
  belongs_to :monthly_satisfaction_survey, inverse_of: :answers

  validates :question_key, presence: true,
                           inclusion: { in: MonthlySatisfactionSurvey::QUESTION_KEYS }
  validates :question_key, uniqueness: { scope: :monthly_satisfaction_survey_id }
  validates :rating, presence: true, inclusion: { in: 1..5 }
end
