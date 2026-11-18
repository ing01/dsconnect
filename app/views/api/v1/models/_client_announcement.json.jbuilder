json.id resource.id
json.title resource.title
json.body resource.body
json.kind resource.kind
json.starts_at resource.starts_at
json.ends_at resource.ends_at
json.link_url resource.link_url
json.link_label resource.link_label
json.position resource.position
json.active resource.active
json.status resource.status
json.audience resource.audience
json.company_ids resource.company_ids
json.companies Company.where(account_id: resource.account_id, id: resource.company_ids).order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } }
json.company_niche_ids resource.company_niche_ids
json.company_sub_niche_ids resource.company_sub_niche_ids
json.classification_levels resource.classification_levels
