# Uma mensagem da conversa do ticket, como o cliente a ve.
#
# Partial proprio, e nao o do painel: aquele carrega `to_email`, `status` de
# entrega e `error_message`, que sao do controle da equipe sobre o envio.
json.id resource.id
json.direction resource.direction
json.subject resource.subject
json.body resource.body
json.closing resource.closing
json.author_name resource.author_name
json.sent_at resource.sent_at&.to_i
json.created_at resource.created_at.to_i
json.attachments resource.ticket_attachments do |anexo|
  json.id anexo.id
  json.filename anexo.file.filename.to_s
  json.content_type anexo.file.content_type
  json.byte_size anexo.file.byte_size
  json.file_url anexo.file_url
end
