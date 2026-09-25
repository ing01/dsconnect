json.array! @categories do |category|
  json.id category.id
  json.name category.name
  # O formulario precisa saber antes de enviar: a Categoria pode exigir anexo.
  json.require_attachment category.require_attachment
end
