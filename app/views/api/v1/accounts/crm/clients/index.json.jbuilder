json.array! @clients do |client|
  json.partial! 'client', client: client
end
