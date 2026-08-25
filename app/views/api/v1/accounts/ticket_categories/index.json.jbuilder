json.array! @ticket_categories do |category|
  json.partial! 'api/v1/models/ticket_category', formats: [:json], resource: category
end
