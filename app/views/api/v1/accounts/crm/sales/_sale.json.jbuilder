json.id sale.id
json.competencia sale.competencia
json.payment_method sale.payment_method
json.installments sale.installments
json.channel sale.channel
json.implementation_value sale.implementation_value
json.monthly_value sale.monthly_value
json.created_at sale.created_at.to_i

json.crm_client_id sale.crm_client_id
json.client_name sale.client&.name

json.user_id sale.user_id
json.seller_name sale.seller&.name

json.items sale.items do |item|
  json.id item.id
  json.product item.product
  json.implementation_value item.implementation_value
  json.monthly_value item.monthly_value
end
