# == Schema Information
#
# Table name: company_categories
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_company_categories_on_account_id           (account_id)
#  index_company_categories_on_account_id_and_name  (account_id,name) UNIQUE
#
class CompanyCategory < ApplicationRecord
  belongs_to :account
  has_many :companies, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :account_id }

  scope :ordered_by_name, -> { order(:name) }
end
