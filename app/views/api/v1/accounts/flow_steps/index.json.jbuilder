json.array! @flow_steps do |flow_step|
  json.partial! 'api/v1/models/flow_step', formats: [:json], resource: flow_step
end
