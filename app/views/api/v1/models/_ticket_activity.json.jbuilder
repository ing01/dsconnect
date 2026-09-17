json.id resource.id
json.ticket_id resource.ticket_id
json.activity_type resource.activity_type
json.previous_value resource.previous_value
json.new_value resource.new_value
json.meta resource.meta
json.created_at resource.created_at.to_i
if resource.user
  json.user do
    json.id resource.user.id
    json.name resource.user.name
    # O historico identifica quem alterou por nome E e-mail: dois "Joao Silva"
    # na mesma conta sao indistinguiveis so pelo nome, e a auditoria precisa
    # apontar uma pessoa.
    json.email resource.user.email
    json.avatar_url resource.user.avatar_url
  end
else
  json.user nil
end
