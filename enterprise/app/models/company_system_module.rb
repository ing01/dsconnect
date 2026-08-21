# == Schema Information
#
# Table name: company_system_modules
#
#  id               :bigint           not null, primary key
#  company_id       :bigint           not null
#  system_module_id :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class CompanySystemModule < ApplicationRecord
  belongs_to :company
  belongs_to :system_module
end
