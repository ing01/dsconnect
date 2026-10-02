json.partial! 'api/v1/models/manifestation', resource: @manifestation

# A equipe ve as DUAS: respostas publicas e anotacoes internas, distinguidas
# pelo `visibility` de cada uma.
json.messages @messages do |message|
  json.partial! 'api/v1/models/manifestation_message', resource: message
end

json.activities @activities do |activity|
  json.partial! 'api/v1/models/manifestation_activity', resource: activity
end
