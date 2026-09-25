# O que a Area do Cliente sabe sobre quem esta logado. So o necessario para a
# tela se identificar - nada do cadastro interno do contato vaza para ca.
json.id resource.id
json.name resource.name
json.email resource.email
json.account_id resource.account_id
json.company_id resource.company_id
json.company_name resource.company&.name
json.tickets_visibility resource.client_tickets_visibility
# O idioma vem da CONTA: a Area do Cliente nao tem usuario interno de quem
# herdar a preferencia, e sem isto a tela renderiza no ingles padrao.
json.locale resource.account.locale
