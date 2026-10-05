json.payload do
  json.array! @surveys do |survey|
    json.partial! 'api/v1/models/monthly_satisfaction_survey', resource: survey
  end
end

# A base da futura tela de resultados: quantidade, media geral e media por
# pergunta - ja calculadas no servidor, pelo RECORTE atual (filtros de
# empresa/mes aplicados antes de chegar aqui).
json.meta do
  json.count @meta[:count]
  # `.to_f` - BigDecimal viraria STRING no JSON (`"3.0"`), e o frontend so
  # sabe somar/comparar numero de verdade.
  json.average_rating @meta[:average_rating]&.round(2)&.to_f
  json.average_by_question do
    MonthlySatisfactionSurvey::QUESTION_KEYS.each do |chave|
      json.set! chave, @meta[:average_by_question][chave]&.round(2)&.to_f
    end
  end
end
