# O sistema e' sempre em portugues (pt_BR) - nunca em ingles (pedido da
# Ingrid ao validar a Central de Ajuda). Todo Portal criado antes do fix em
# CreatePortalDialog.vue nasceu com `allowed_locales: ['en']` (o default da
# coluna `config`), e toda Categoria/Artigo criado nele herdou locale "en"
# tambem (Article#ensure_locale_in_article copia da Categoria) - por isso a
# tela principal do portal e o "Home > Uncategorized" apareciam em ingles,
# mesmo com o conteudo escrito em portugues.
#
# Esta migracao:
# 1. Forca TODO Portal a ficar so' com pt_BR (default_locale e
#    allowed_locales).
# 2. Reclassifica pra pt_BR as Categorias que nao estavam (pulando, com
#    aviso no log, qualquer conflito de slug com uma Categoria pt_BR ja
#    existente - nao deveria acontecer num sistema que so' usou "en" ate
#    agora, mas fica seguro contra isso).
# 3. Artigos SEM categoria sao corrigidos direto; Artigos COM categoria sao
#    resalvos - o callback `ensure_locale_in_article` do model ja copia o
#    locale da Categoria (corrigida no passo 2) sozinho.
class FixHelpCenterLocaleToPtBr < ActiveRecord::Migration[7.2]
  def up
    Portal.find_each do |portal|
      fix_portal_config(portal)
      fix_categories(portal)
      fix_uncategorized_articles(portal)
      fix_categorized_articles(portal)
    end
  end

  def down
    # Nao reverte - o sistema sempre vai continuar so' em pt_BR.
  end

  private

  def fix_portal_config(portal)
    portal.update!(config: portal.config.to_h.merge(
      'default_locale' => 'pt_BR',
      'allowed_locales' => ['pt_BR'],
      'draft_locales' => []
    ))
  end

  def fix_categories(portal)
    portal.categories.where.not(locale: 'pt_BR').find_each do |category|
      category.update!(locale: 'pt_BR')
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[FixHelpCenterLocaleToPtBr] categoria #{category.id} (slug #{category.slug}): #{e.message}")
    end
  end

  def fix_uncategorized_articles(portal)
    portal.articles.where(category_id: nil).where.not(locale: 'pt_BR').update_all(locale: 'pt_BR')
  end

  def fix_categorized_articles(portal)
    portal.articles.where.not(category_id: nil).where.not(locale: 'pt_BR').find_each do |article|
      article.save!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[FixHelpCenterLocaleToPtBr] artigo #{article.id} (slug #{article.slug}): #{e.message}")
    end
  end
end
