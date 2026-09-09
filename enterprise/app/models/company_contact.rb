# == Schema Information
#
# Table name: company_contacts
#
#  id         :bigint           not null, primary key
#  contact_id :bigint           not null
#  company_id :bigint           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class CompanyContact < ApplicationRecord
  belongs_to :contact
  belongs_to :company
end
