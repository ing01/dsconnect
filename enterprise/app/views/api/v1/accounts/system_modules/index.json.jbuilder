json.payload do
  json.array! @system_modules do |system_module|
    json.partial! 'api/v1/models/system_module', formats: [:json], resource: system_module
  end
end
