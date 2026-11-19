json.partial! 'api/v1/models/ticket_proposal', formats: [:json], resource: @ticket_proposal
# So' na criacao com "enviar por e-mail": como foi o envio (sent, reason, to).
if @email_result
  json.email do
    json.sent @email_result.sent
    json.reason @email_result.reason
    json.to @email_result.to
  end
end
