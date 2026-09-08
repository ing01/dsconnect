json.partial! 'api/v1/models/automation_flow_run', resource: @flow_run
# O detalhe traz as etapas: e o que responde "em que ponto parou e por que".
json.events @events do |event|
  json.id event.id
  json.step_id event.step_id
  json.step_type event.step_type
  json.outcome event.outcome
  json.input event.input
  json.result event.result
  json.error event.error
  json.created_at event.created_at.to_i
end
