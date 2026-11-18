# Muitos-pra-muitos: um item do Catalogo de Servicos pode carregar varios
# Formularios, e um Formulario pode servir mais de um item.
class CreateServiceCatalogItemForms < ActiveRecord::Migration[7.2]
  def change
    create_table :service_catalog_item_forms do |t|
      t.references :service_catalog_item, null: false, foreign_key: true
      t.references :form, null: false, foreign_key: true

      t.timestamps
    end

    add_index :service_catalog_item_forms, %i[service_catalog_item_id form_id], unique: true,
                                                                                  name: 'idx_catalog_item_forms_unique'
  end
end
