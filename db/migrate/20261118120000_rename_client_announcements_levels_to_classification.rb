# O filtro por "Nivel" do Mural e' o Nivel de classificacao da Empresa (1 a 5,
# o da planilha Nicho/Subnicho/Nivel), e nao a Prioridade (`client_level`).
class RenameClientAnnouncementsLevelsToClassification < ActiveRecord::Migration[7.0]
  def up
    rename_column :client_announcements, :client_levels, :classification_levels
    # Os valores antigos eram Prioridade (1..3) e nao tem equivalente em Nivel:
    # zerar evita um aviso segmentado apontando para o filtro errado.
    execute "UPDATE client_announcements SET classification_levels = '{}'"
    # Aviso segmentado que so' tinha Prioridade ficaria sem nenhum filtro.
    execute <<~SQL.squish
      UPDATE client_announcements SET audience = 'all'
      WHERE audience = 'segmented' AND company_ids = '{}' AND company_niche_ids = '{}' AND company_sub_niche_ids = '{}'
    SQL
  end

  def down
    rename_column :client_announcements, :classification_levels, :client_levels
  end
end
