json.payload @runs do |run|
  json.id run.id
  json.status run.status
  json.current_step_id run.current_step_id
  json.last_error run.last_error
  json.automation_rule_id run.automation_rule_id
  json.automation_rule_name run.automation_rule&.name
  json.created_at run.created_at.to_i
  json.updated_at run.updated_at.to_i
  json.events run.events.sort_by(&:created_at) do |flow_event|
    json.id flow_event.id
    json.step_id flow_event.step_id
    json.step_type flow_event.step_type
    json.outcome flow_event.outcome
    json.error flow_event.error
    json.result flow_event.result
    json.created_at flow_event.created_at.to_i
  end
end
