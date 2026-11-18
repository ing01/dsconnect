json.id resource.id
json.account_id resource.account_id
json.name resource.name
json.description resource.description
json.status resource.status
json.fields resource.fields
json.theme resource.theme
json.article_id resource.article_id
# Publicacao na Central de Ajuda: quem pode preencher (login/open), o texto de depois do envio e os
# links para copiar. `public_url` so' existe no formulario aberto e publicado.
json.access_mode resource.access_mode
json.success_message resource.success_message
json.client_url (resource.published? ? Forms::Links.client_url(resource) : nil)
json.public_url (resource.published? ? Forms::Links.public_url(resource) : nil)
json.article (resource.article ? { id: resource.article.id, title: resource.article.title } : nil)
json.service_catalog_item_ids resource.service_catalog_item_ids
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
