class ServiceCatalogItemForm < ApplicationRecord
  belongs_to :service_catalog_item
  belongs_to :form

  validates :form_id, uniqueness: { scope: :service_catalog_item_id }
end
