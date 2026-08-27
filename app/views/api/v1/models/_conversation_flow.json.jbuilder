json.id resource.id
json.name resource.name
json.description resource.description
json.active resource.active
json.account_id resource.account_id
json.flow_steps resource.flow_steps do |flow_step|
  json.partial! 'api/v1/models/flow_step', formats: [:json], resource: flow_step
end
