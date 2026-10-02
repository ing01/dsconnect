json.payload do
  json.array! @manifestations do |manifestation|
    json.partial! 'api/v1/models/manifestation', resource: manifestation
  end
end

# Os contadores do topo: total, pendentes e as que ninguem abriu ainda.
json.meta do
  json.total @counts[:total]
  json.pending @counts[:pending]
  json.untouched @counts[:untouched]
end
