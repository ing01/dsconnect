json.array! @modules do |tutorial_module|
  json.partial! 'api/v1/models/client_tutorial_module', formats: [:json], resource: tutorial_module
end
