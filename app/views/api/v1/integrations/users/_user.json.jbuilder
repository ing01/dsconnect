json.id user.id
json.name user.name
json.email user.email
json.role roles[user.id]
# Os Nichos e Sub-nichos de empresa que o usuario atende (listas vazias quando nenhum).
json.niches Array(niches[user.id]).map { |link| { id: link.company_niche.id, name: link.company_niche.name } }.sort_by { |n| n[:name].to_s }
json.sub_niches Array(sub_niches[user.id]).map { |link| { id: link.company_sub_niche.id, name: link.company_sub_niche.name } }.sort_by { |n| n[:name].to_s }
