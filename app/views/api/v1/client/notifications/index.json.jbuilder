json.array! @communications do |com|
  json.id com.id
  json.ticket_id com.ticket_id
  json.ticket_display_id com.ticket.display_id
  json.ticket_title com.ticket.title
  json.subject com.subject
  # Um resumo: a lista e para decidir o que abrir, nao para ler a mensagem
  # inteira - essa fica na aba Comunicacao do chamado.
  json.preview com.body.to_s.truncate(160)
  json.author_name com.user&.name
  json.closing com.closing
  json.created_at (com.sent_at || com.created_at).to_i
end
