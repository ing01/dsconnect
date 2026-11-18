# Reorganiza a arvore da Base de Conhecimento: leva um Artigo (com todos os subartigos dele)
# para outra pasta (Categoria) ou para baixo de outro Artigo, na posicao pedida.
#
# - `parent`: o novo artigo-pai (nil = vai para a raiz da pasta);
# - `category`: a pasta de destino, usada quando nao ha pai (com pai, vale a pasta do pai);
# - `index`: a posicao entre os irmaos (0 = primeiro); em branco, vai para o fim.
#
# A pasta tem de ser do mesmo portal e do mesmo idioma do artigo: a arvore e' por idioma, e
# mover para outra pasta nao pode, em silencio, trocar o idioma do artigo.
class Articles::TreeMover
  class InvalidMove < StandardError; end

  pattr_initialize [:article!, :parent, :category, :index]

  def perform
    Article.transaction do
      check_targets!
      move_article
      move_descendants
      place_among_siblings
    end
    article.reload
  end

  private

  def target_category
    parent ? parent.category : category
  end

  def check_targets!
    raise InvalidMove, 'a pasta precisa ser do mesmo portal' if category && category.portal_id != article.portal_id
    raise InvalidMove, 'a pasta precisa ser do mesmo idioma do artigo' if target_category && target_category.locale != article.locale
  end

  def move_article
    article.parent_article = parent
    article.category = target_category
    article.save!
  rescue ActiveRecord::RecordInvalid => e
    raise InvalidMove, e.record.errors.full_messages.to_sentence
  end

  # Os subartigos acompanham o pai: ficam na mesma pasta.
  def move_descendants
    ids = article.descendant_articles.map(&:id)
    return if ids.empty?

    # rubocop:disable Rails/SkipsModelValidations
    Article.where(id: ids).update_all(category_id: article.category_id)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def siblings_without_article
    Article.where(portal_id: article.portal_id, locale: article.locale,
                  category_id: article.category_id, parent_article_id: article.parent_article_id)
           .where.not(id: article.id).order(:position, :id).to_a
  end

  def place_among_siblings
    siblings = siblings_without_article
    siblings.insert(index.nil? ? siblings.size : index.to_i.clamp(0, siblings.size), article)
    siblings.each_with_index { |sibling, i| write_position(sibling, (i + 1) * 10) }
  end

  def write_position(sibling, position)
    return if sibling.position == position

    # rubocop:disable Rails/SkipsModelValidations
    sibling.update_column(:position, position)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
