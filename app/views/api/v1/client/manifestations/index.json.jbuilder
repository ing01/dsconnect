json.payload do
  json.array! @manifestations do |manifestation|
    json.partial! 'api/v1/models/manifestation', resource: manifestation
  end
end
