# Arvore da Base de Conhecimento: um Artigo pode ter outros Artigos como filhos (subartigos),
# sem pasta intermediaria. As pastas continuam sendo as Categorias (e suas subcategorias).
# `associated_article_id` NAO serve para isso: ele liga as traducoes do mesmo artigo.
class AddParentArticleToArticles < ActiveRecord::Migration[7.2]
  def change
    add_column :articles, :parent_article_id, :bigint
    add_index :articles, :parent_article_id
  end
end
