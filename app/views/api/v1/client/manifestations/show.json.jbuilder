json.partial! 'api/v1/models/manifestation', resource: @manifestation

# `@messages` chega do controller JA filtrado por `visible_to_client`. A view nao
# decide o que e visivel - se decidisse, cada tela nova teria de lembrar da
# regra.
json.messages @messages do |message|
  json.partial! 'api/v1/models/manifestation_message', resource: message
end

json.activities @activities do |activity|
  json.partial! 'api/v1/models/manifestation_activity', resource: activity
end
