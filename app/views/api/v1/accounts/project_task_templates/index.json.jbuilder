json.array! @project_task_templates do |project_task_template|
  json.partial! 'api/v1/models/project_task_template', formats: [:json], resource: project_task_template
end
