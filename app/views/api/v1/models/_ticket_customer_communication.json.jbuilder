json.id resource.id
json.to_email resource.to_email
json.subject resource.subject
json.body resource.body
json.channel resource.channel
json.status resource.status
# Se a mensagem saiu por e-mail ou foi apenas registrada no chamado. A tela
# precisa distinguir: `skipped` nao e falha, e uma escolha de quem enviou.
json.notify_customer resource.notify_customer
json.closing resource.closing
json.error_message resource.error_message
json.sent_at resource.sent_at&.to_i
json.created_at resource.created_at.to_i
json.user_name resource.user&.name
json.contact_name resource.contact&.name
# `inbound` e a resposta escrita pelo cliente na Area do Cliente. A tela precisa
# distinguir: quem escreveu, e para quem, muda conforme o sentido.
json.direction resource.direction
json.author_name resource.author_name
json.attachments resource.ticket_attachments do |anexo|
  json.partial! 'api/v1/models/ticket_attachment', formats: [:json], resource: anexo
end
