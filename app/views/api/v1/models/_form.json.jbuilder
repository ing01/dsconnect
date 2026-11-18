json.id resource.id
json.account_id resource.account_id
json.name resource.name
json.description resource.description
json.status resource.status
json.fields resource.fields
json.theme resource.theme
json.article_id resource.article_id
json.article (resource.article ? { id: resource.article.id, title: resource.article.title } : nil)
json.service_catalog_item_ids resource.service_catalog_item_ids
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
