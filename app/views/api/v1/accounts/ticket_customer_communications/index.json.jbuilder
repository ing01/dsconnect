json.payload do
  json.array! @communications do |communication|
    json.partial! 'api/v1/models/ticket_customer_communication', formats: [:json], resource: communication
  end
end
