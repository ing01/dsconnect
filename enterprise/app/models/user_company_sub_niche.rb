# Vinculo do agente (analista) com um Sub-nicho de empresa. Ver CreateUserCompanyNiches.
class UserCompanySubNiche < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :company_sub_niche

  validates :company_sub_niche_id, uniqueness: { scope: :user_id }
  validate :same_account

  private

  def same_account
    return if company_sub_niche.nil? || company_sub_niche.account_id == account_id

    errors.add(:company_sub_niche, 'é de outra conta')
  end
end
