json.payload do
  json.partial! 'article', article: @article
  # O conteudo ja em HTML, com as referencias a outros artigos/formularios marcadas para a tela
  # navegar dentro da Base de Conhecimento (ver Articles::ReferenceResolver).
  json.rendered_content ::Articles::ReferenceResolver.new(
    html: ChatwootMarkdownRenderer.new(@article.content.to_s).render_article, portal: @portal, mode: :dashboard
  ).call.to_s
  # Do mais alto para o pai direto: o caminho "Pasta > POP 1 > POP 1.1" da tela.
  json.ancestors @article.ancestor_articles.reverse do |ancestor|
    json.id ancestor.id
    json.title ancestor.title
  end
  # Os formularios que documentam este artigo (so' os publicados: os rascunhos ainda nao servem).
  json.forms @article.forms.published.order(:name) do |form|
    json.id form.id
    json.name form.name
    json.description form.description
    json.fields form.fields
  end
end
