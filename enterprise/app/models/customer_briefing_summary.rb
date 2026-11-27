# == Schema Information
#
# Table name: customer_briefing_summaries
#
#  id          :bigint           not null, primary key
#  content     :jsonb            not null
#  fingerprint :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  company_id  :bigint
#  contact_id  :bigint           not null
#
class CustomerBriefingSummary < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :company, optional: true

  validates :fingerprint, presence: true, uniqueness: { scope: :account_id }
end
