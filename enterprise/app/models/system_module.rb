# == Schema Information
#
# Table name: system_modules
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
class SystemModule < ApplicationRecord
  belongs_to :account
  has_many :company_system_modules, dependent: :destroy
  has_many :companies, through: :company_system_modules

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :account_id }

  scope :ordered_by_name, -> { order(:name) }
end
