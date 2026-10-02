# O corpo de uma manifestacao, SEM mensagens e SEM anotacoes.
#
# As mensagens ficam fora de proposito: e o unico lugar onde publico e interno se
# separam, e cada lado as monta com o seu proprio filtro. Um partial que
# devolvesse "as mensagens" seria o caminho mais curto para vazar uma nota.
json.id resource.id
json.display_id resource.display_id
json.reference resource.reference
json.kind resource.kind
json.subject_area resource.subject_area
json.status resource.status
json.title resource.title
json.description resource.description
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i

json.company_id resource.company_id
json.company_name resource.company&.name
json.contact_id resource.contact_id
json.contact_name resource.contact&.name

json.assignee_id resource.assignee_id
json.assignee_name resource.assignee&.name

# A conversao: o cliente ve que o caso virou um chamado, e a equipe usa isto
# para nao converter duas vezes.
json.converted resource.converted?
json.converted_ticket_id resource.converted_ticket_id
json.converted_ticket_display_id resource.converted_ticket&.display_id
json.converted_at resource.converted_at&.to_i

json.attachments resource.manifestation_attachments do |anexo|
  json.id anexo.id
  json.name anexo.file_name
  json.byte_size anexo.byte_size
  json.url anexo.file_url
end
