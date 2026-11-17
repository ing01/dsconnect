# Mesmo padrao de `CreateCompanyNiches` (20261109130000) - lista por conta,
# criada livremente, agora para o "Subnicho" (pedido da Ingrid, 2026-11-17).
class CreateCompanySubNiches < ActiveRecord::Migration[7.2]
  def change
    create_table :company_sub_niches do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :company_sub_niches, %i[account_id name], unique: true
  end
end
