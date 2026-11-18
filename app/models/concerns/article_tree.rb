# A arvore da Base de Conhecimento: um Artigo pode ter outros Artigos como filhos (subartigos).
# As pastas continuam sendo as Categorias; o filho mora na pasta e no idioma do pai, sem pasta
# intermediaria. Ao excluir o pai, os filhos sobem um nivel.
#
# `associated_article_id` NAO serve para isso: ele liga as traducoes do mesmo artigo.
module ArticleTree
  extend ActiveSupport::Concern

  MAX_TREE_DEPTH = 8

  included do
    has_many :child_articles,
             class_name: :Article,
             foreign_key: :parent_article_id,
             inverse_of: :parent_article,
             dependent: nil
    belongs_to :parent_article,
               class_name: :Article,
               inverse_of: :child_articles,
               optional: true

    before_validation :inherit_parent_category
    validate :parent_article_fits_in_tree
    before_destroy :lift_child_articles
  end

  # Os ancestrais, do pai ate a raiz (para o caminho "Pasta > POP 1 > POP 1.1" e a checagem de ciclo).
  def ancestor_articles
    chain = []
    current = parent_article
    while current && chain.exclude?(current) && chain.size <= MAX_TREE_DEPTH
      chain << current
      current = current.parent_article
    end
    chain
  end

  # Todos os descendentes (filhos, netos...), sem repetir e sem laco.
  def descendant_articles
    found = []
    queue = [self]
    until queue.empty?
      children = self.class.where(parent_article_id: queue.map(&:id)).where.not(id: found.map(&:id) + [id]).to_a
      found.concat(children)
      queue = children
    end
    found
  end

  private

  def parent_article_fits_in_tree
    return if parent_article_id.blank?

    message = parent_article_problem
    errors.add(:parent_article, message) if message
  end

  # Uma sequencia de regras, da mais basica a mais cara: a primeira violada vira a mensagem.
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def parent_article_problem
    parent = parent_article
    return 'não existe' if parent.nil?
    return 'não pode ser o próprio artigo' if persisted? && parent.id == id
    return 'precisa ser do mesmo portal' if parent.portal_id != portal_id
    return 'precisa ser do mesmo idioma' if parent.locale != locale

    ancestors = parent.ancestor_articles
    return 'não pode ser um subartigo deste artigo' if persisted? && ancestors.map(&:id).include?(id)

    "ultrapassa o limite de #{MAX_TREE_DEPTH} níveis" if ancestors.size + 1 >= MAX_TREE_DEPTH
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # O subartigo mora na pasta (Categoria) do pai, sem pasta intermediaria.
  def inherit_parent_category
    return if parent_article_id.blank?

    parent = parent_article
    self.category_id = parent.category_id if parent && category_id != parent.category_id
  end

  # Os filhos de um artigo excluido sobem para o pai dele (ou para a raiz da pasta).
  def lift_child_articles
    # rubocop:disable Rails/SkipsModelValidations
    child_articles.update_all(parent_article_id: parent_article_id)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
