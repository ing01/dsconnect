# Os nichos e sub-nichos de empresa que cada agente (analista) atende. So' cadastro e consulta por
# enquanto: nada nas empresas muda sozinho a partir disto. Muitos para muitos - dois analistas
# podem dividir o mesmo sub-nicho (Informatica, Construcao civil). Apagar o agente ou o nicho leva o
# vinculo junto (cascade no banco).
class CreateUserCompanyNiches < ActiveRecord::Migration[7.2]
  def change
    create_table :user_company_niches do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :company_niche, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :user_company_niches, %i[user_id company_niche_id], unique: true, name: 'index_user_company_niches_on_user_and_niche'

    create_table :user_company_sub_niches do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :company_sub_niche, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :user_company_sub_niches, %i[user_id company_sub_niche_id], unique: true, name: 'index_user_company_sub_niches_on_user_and_sub_niche'
  end
end
