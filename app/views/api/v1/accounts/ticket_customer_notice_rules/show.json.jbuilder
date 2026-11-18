json.payload do
  json.partial! 'api/v1/models/ticket_customer_notice_rule', formats: [:json], resource: @rule
end
