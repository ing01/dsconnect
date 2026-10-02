class Crm::SaleItem < ApplicationRecord
  self.table_name = 'crm_sale_items'

  belongs_to :sale, class_name: 'Crm::Sale', foreign_key: 'crm_sale_id', inverse_of: :items

  validates :product, presence: true
end
