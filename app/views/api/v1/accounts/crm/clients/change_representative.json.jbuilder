json.client do
  json.partial! 'client', client: @client
end

json.results @results
