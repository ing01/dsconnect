# == Schema Information
#
# Table name: product_groups
#
#  id               :bigint           not null, primary key
#  name             :string           not null
#  total_value      :decimal(12, 2)
#  total_value_mode :string           default("auto"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
class ProductGroup < ApplicationRecord
  TOTAL_VALUE_MODES = %w[auto manual].freeze

  belongs_to :account
  has_many :products, dependent: :restrict_with_error
  has_many :contract_product_groups, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :account_id }
  validates :total_value_mode, inclusion: { in: TOTAL_VALUE_MODES }
  validates :total_value, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  scope :ordered_by_name, -> { order(:name) }

  # Soma do `value` de cada Produto do grupo (padrao), a menos que tenha sido
  # sobrescrito manualmente - e' o valor que preenche a linha do contrato
  # quando esse grupo e' selecionado (ver ContractFormDialog no frontend).
  def computed_value
    return total_value.to_d if total_value_mode == 'manual' && total_value.present?

    products.sum { |product| product.value || 0 }
  end
end
