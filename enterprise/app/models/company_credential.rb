# == Schema Information
#
# Table name: company_credentials
#
#  id                :bigint           not null, primary key
#  anydesk_id        :string
#  anydesk_password  :text
#  db_host           :string
#  db_name           :string
#  db_password       :text
#  db_port           :integer
#  db_type           :string
#  db_username       :string
#  label             :string
#  notes             :text
#  rdp_address       :string
#  rdp_password      :text
#  rdp_username      :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  company_id        :bigint           not null
#  created_by_id     :bigint
#  updated_by_id     :bigint
#
class CompanyCredential < ApplicationRecord
  DB_TYPES = %w[postgresql mysql mariadb sqlserver oracle mongodb other].freeze

  belongs_to :account
  belongs_to :company
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  encrypts :db_password
  encrypts :anydesk_password
  encrypts :rdp_password

  validates :label, presence: true, length: { maximum: 100 }
  validates :db_type, inclusion: { in: DB_TYPES }, allow_blank: true
  validates :db_port, numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }, allow_blank: true
end
