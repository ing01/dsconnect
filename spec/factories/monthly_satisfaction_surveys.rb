FactoryBot.define do
  factory :monthly_satisfaction_survey do
    account
    company { create(:company, account: account) }
    contact { create(:contact, account: account, company: company) }
    reference_month { MonthlySatisfactionSurvey.current_reference_month }
    comment { nil }

    # As dez respostas, todas com nota 4, para quem precisar de uma avaliacao
    # completa sem se importar com os valores exatos.
    after(:create) do |survey|
      MonthlySatisfactionSurvey::QUESTION_KEYS.each do |chave|
        survey.answers.create!(question_key: chave, rating: 4)
      end
    end
  end

  factory :monthly_satisfaction_survey_answer do
    monthly_satisfaction_survey
    question_key { MonthlySatisfactionSurvey::QUESTION_KEYS.first }
    rating { 4 }
  end
end
