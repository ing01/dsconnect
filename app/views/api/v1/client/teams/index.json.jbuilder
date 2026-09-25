json.array! @teams do |team|
  json.id team.id
  json.name team.name
  # `client_visible`: a mesma fronteira do endpoint de Categorias. Aqui a lista
  # sai por Mesa, mas ainda e o cliente lendo - nao pode mostrar o que a tela de
  # Configuracoes deixou oculto para ele.
  json.categories team.ticket_categories.client_visible do |category|
    json.id category.id
    json.name category.name
    # O formulario do cliente precisa saber antes de enviar: a Categoria pode
    # exigir anexo.
    json.require_attachment category.require_attachment
  end
end
