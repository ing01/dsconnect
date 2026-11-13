json.array! @tutorials do |tutorial|
  json.partial! 'api/v1/models/client_tutorial', formats: [:json], resource: tutorial
end
