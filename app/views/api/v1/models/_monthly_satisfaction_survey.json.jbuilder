# Uma avaliacao mensal, com as dez respostas. So lida pelo lado INTERNO - o
# cliente nunca ve este payload, so o status (`show`/`create` do controller
# dele, que respondem um JSON proprio, sem jbuilder).
json.id resource.id
json.reference_month resource.reference_month.iso8601
json.comment resource.comment
json.created_at resource.created_at.to_i

json.company_id resource.company_id
json.company_name resource.company&.name
json.contact_id resource.contact_id
json.contact_name resource.contact&.name

json.average_rating resource.average_rating&.round(2)&.to_f

json.answers resource.answers do |resposta|
  json.question_key resposta.question_key
  json.rating resposta.rating
end
