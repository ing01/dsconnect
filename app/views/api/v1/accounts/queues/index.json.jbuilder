json.array! @queues do |queue|
  json.partial! 'api/v1/models/queue', formats: [:json], resource: queue
end
