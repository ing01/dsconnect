# Uma mensagem da manifestacao.
#
# `visibility` vai no corpo de proposito: a tela INTERNA precisa diferenciar
# resposta de anotacao com clareza. Na Area do Cliente este partial so e
# alcancado por registros ja filtrados por `visible_to_client`.
json.id resource.id
json.visibility resource.visibility
json.body resource.body
json.created_at resource.created_at.to_i
json.from_client resource.from_client?
json.author_name resource.author_name
