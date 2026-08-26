class AddServiceCatalogItemToTickets < ActiveRecord::Migration[7.2]
  def change
    # Nullable: a ticket is classified during its life, and every ticket that
    # already exists was opened before the catalogue did.
    add_reference :tickets, :service_catalog_item, foreign_key: { on_delete: :restrict }, null: true
  end
end
