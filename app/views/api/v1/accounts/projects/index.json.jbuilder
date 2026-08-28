json.array! @projects do |project|
  json.partial! 'api/v1/models/project', formats: [:json], resource: project
end
