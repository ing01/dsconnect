# Campo novo, INDEPENDENTE do `company_niche_id' (20261109140000) - "Subnicho"
# e' uma segunda classificacao, nao um filho obrigatorio do Nicho (pedido da
# Ingrid, 2026-11-17).
class AddCompanySubNicheToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_reference :companies, :company_sub_niche, foreign_key: true, index: true
  end
end
