# == Schema Information
#
# Table name: products
#
#  id               :bigint           not null, primary key
#  name             :string           not null
#  value            :decimal(12, 2)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  product_group_id :bigint           not null
#
class Product < ApplicationRecord
  belongs_to :account
  belongs_to :product_group

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :account_id }
  validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  scope :ordered_by_name, -> { order(:name) }
end
