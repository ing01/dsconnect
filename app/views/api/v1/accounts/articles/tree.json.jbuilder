# A arvore de um idioma: as pastas (Categorias, com a categoria-mae) e os artigos (com o artigo-pai),
# so' com o necessario para desenhar a hierarquia. O conteudo de cada artigo vem do `show`.
json.locale @locale

json.categories @categories do |category|
  json.id category.id
  json.name category.name
  json.slug category.slug
  json.locale category.locale
  json.position category.position
  json.parent_category_id category.parent_category_id
  json.icon category.icon
  json.icon_color category.icon_color
end

json.articles @articles do |article|
  json.id article.id
  json.slug article.slug
  json.title article.title
  json.status article.status
  json.position article.position
  json.category_id article.category_id
  json.parent_article_id article.parent_article_id
  json.views article.views
end
