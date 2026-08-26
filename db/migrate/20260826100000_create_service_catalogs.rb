class CreateServiceCatalogs < ActiveRecord::Migration[7.2]
  # Three levels: Catalogo -> Area -> Item. The Ticket references only the Item;
  # the two levels above it are reached through the association, so no name is
  # ever duplicated onto the ticket.
  def change
    create_catalogs
    create_areas
    create_items
  end

  def create_catalogs
    create_table :service_catalogs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      # Records already used by tickets are deactivated, never deleted.
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :service_catalogs, [:account_id, :name], unique: true
    add_index :service_catalogs, [:account_id, :position]
  end

  def create_areas
    create_table :service_catalog_areas do |t|
      t.references :service_catalog, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :service_catalog_areas, [:service_catalog_id, :name], unique: true
  end

  def create_items
    create_table :service_catalog_items do |t|
      t.references :service_catalog_area, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :service_catalog_items, [:service_catalog_area_id, :name], unique: true
  end
end
