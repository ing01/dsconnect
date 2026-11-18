json.payload do
  json.array! @rules do |rule|
    json.partial! 'api/v1/models/ticket_customer_notice_rule', formats: [:json], resource: rule
  end
end
