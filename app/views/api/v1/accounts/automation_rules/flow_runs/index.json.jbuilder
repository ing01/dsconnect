json.payload do
  json.array! @flow_runs do |run|
    json.partial! 'api/v1/models/automation_flow_run', resource: run
  end
end
json.meta do
  json.count @flow_runs.total_count
  json.current_page @flow_runs.current_page
end
