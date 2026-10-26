json.array! @sprints do |sprint|
  json.partial! 'api/v1/models/sprint', formats: [:json], resource: sprint
end
