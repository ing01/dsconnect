# As referencias entre artigos e formularios que o autor insere no conteudo:
#   [POP 1.1](/dsref/article/12)   e   [Abertura](/dsref/form/3)
# (e' um caminho relativo de proposito: passa na sanitizacao de links do editor e do navegador).
#
# - modo `:dashboard`: o link continua e ganha `data-ref-type`/`data-ref-id`, que a tela usa para
#   navegar dentro da Base de Conhecimento. Referencia a algo que nao existe mais ganha
#   `data-ref-broken`, para a tela avisar em vez de levar a lugar nenhum.
# - modo `:public` (Portal do cliente): o artigo publicado vira o link publico dele e o formulario
#   publicado vira o link para preencher (Forms::Links); artigo rascunho/arquivado/excluido e
#   formulario nao publicado viram texto, sem link morto.
class Articles::ReferenceResolver
  REFERENCE = %r{\A/dsref/(article|form)/(\d+)\z}

  pattr_initialize [:html!, :portal!, { mode: :dashboard }]

  def call
    return html if html.blank? || html.exclude?('/dsref/')

    fragment = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
    fragment.css('a[href^="/dsref/"]').each { |link| resolve(link) }
    result = fragment.to_html
    # O HTML ja era seguro (renderizado pelo servidor); so' devolvemos a marca que ele tinha.
    # rubocop:disable Rails/OutputSafety
    html.respond_to?(:html_safe?) && html.html_safe? ? result.html_safe : result
    # rubocop:enable Rails/OutputSafety
  end

  private

  def resolve(link)
    match = REFERENCE.match(link['href'].to_s)
    return unwrap(link) unless match

    type = match[1]
    target = find_target(type, match[2])
    mode == :public ? resolve_public(link, type, target) : resolve_dashboard(link, type, match[2], target)
  end

  def resolve_dashboard(link, type, id, target)
    link['data-ref-type'] = type
    link['data-ref-id'] = id
    link['data-ref-broken'] = 'true' if target.nil?
  end

  def resolve_public(link, type, target)
    return unwrap(link) unless target&.published?

    link['href'] = type == 'article' ? "/hc/#{portal.slug}/articles/#{target.slug}" : Forms::Links.fill_url(target)
  end

  def unwrap(link)
    link.replace(link.children)
  end

  def find_target(type, id)
    return portal.articles.find_by(id: id) if type == 'article'

    portal.account.forms.find_by(id: id)
  end
end
