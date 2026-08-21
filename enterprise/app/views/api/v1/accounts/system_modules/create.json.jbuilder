json.payload do
  json.partial! 'api/v1/models/system_module', formats: [:json], resource: @system_module
end
