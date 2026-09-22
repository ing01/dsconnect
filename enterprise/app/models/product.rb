# == Schema Information
#
# Table name: products
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
class Product < ApplicationRecord
  belongs_to :account
  has_many :contract_products, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :account_id }

  scope :ordered_by_name, -> { order(:name) }
end
