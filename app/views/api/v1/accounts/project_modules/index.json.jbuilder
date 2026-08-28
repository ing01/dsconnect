json.array! @project_modules do |project_module|
  json.partial! 'api/v1/models/project_module', formats: [:json], resource: project_module
end
