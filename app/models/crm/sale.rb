# Uma venda do Painel Comercial - sempre de um `Crm::Client`, com um ou mais
# itens de produto (`Crm::SaleItem`). `implementation_value`/`monthly_value`
# nunca sao digitados direto: sao sempre a soma dos itens (mesma regra do
# painel standalone atual) - ver `sync_totals_from_items`.
class Crm::Sale < ApplicationRecord
  self.table_name = 'crm_sales'

  belongs_to :account
  belongs_to :client, class_name: 'Crm::Client', foreign_key: 'crm_client_id', inverse_of: :sales
  belongs_to :seller, class_name: 'User', foreign_key: 'user_id', optional: true

  has_many :items, class_name: 'Crm::SaleItem', foreign_key: 'crm_sale_id', dependent: :destroy, inverse_of: :sale
  accepts_nested_attributes_for :items, allow_destroy: true

  validates :competencia, presence: true

  before_save :sync_totals_from_items

  private

  def sync_totals_from_items
    pending_items = items.reject(&:marked_for_destruction?)
    self.implementation_value = pending_items.sum { |item| item.implementation_value || 0 }
    self.monthly_value = pending_items.sum { |item| item.monthly_value || 0 }
  end
end
