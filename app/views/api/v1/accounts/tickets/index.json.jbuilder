json.meta do
  json.count @tickets_count
  json.current_page @current_page
end

json.payload do
  json.array! @tickets do |ticket|
    json.partial! 'api/v1/models/ticket', formats: [:json], resource: ticket
  end
end
