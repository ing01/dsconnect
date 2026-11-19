json.id company.id
json.name company.name
json.legal_name company.legal_name
json.cnpj company.cnpj
json.codigo company.codigo
json.domain company.domain
# Nivel da Empresa, de 1 a 5 (nulo quando nao classificada).
json.classification_level company.classification_level
json.blocked company.blocked
# Nicho e Sub-nicho da empresa (nulos quando nao informados): o par que decide quem atende.
json.niche company.company_niche && { id: company.company_niche.id, name: company.company_niche.name }
json.sub_niche company.company_sub_niche && { id: company.company_sub_niche.id, name: company.company_sub_niche.name }
