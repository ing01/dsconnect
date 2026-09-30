json.id resource.id
json.name resource.name
json.position resource.position
json.active resource.active
# O peso existe para o calculo de custo por cliente que vem depois; hoje nenhuma
# tela o usa, e vai no payload para a etapa seguinte nao mexer no serializer.
json.weight resource.weight
# Quais Mesas oferecem este nivel - a matriz da tela de configuracao e o filtro
# do formulario de ticket. `team_ids` vem pre-carregado pela listagem; no
# create/update, do proprio registro.
json.team_ids(
  if defined?(team_ids) && team_ids
    team_ids
  else
    resource.ticket_complexity_teams.map(&:team_id)
  end
)
