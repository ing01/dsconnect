# == Schema Information
#
# Table name: contract_products
#
#  id                  :bigint           not null, primary key
#  implementation_fee  :decimal(12, 2)
#  licenses_qty         :integer          default(1), not null
#  unit_value          :decimal(12, 2)   default(0.0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  contract_id         :bigint           not null
#  product_id          :bigint           not null
#
class ContractProduct < ApplicationRecord
  belongs_to :contract
  belongs_to :product

  validates :unit_value, numericality: { greater_than_or_equal_to: 0 }
  validates :licenses_qty, numericality: { only_integer: true, greater_than: 0 }
  validates :implementation_fee, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  # Uma linha do contrato: N licencas de um produto pelo valor unitario, mais
  # a implantacao (unica, nao multiplicada pela quantidade de licencas).
  def subtotal
    (unit_value * licenses_qty) + (implementation_fee || 0)
  end
end
