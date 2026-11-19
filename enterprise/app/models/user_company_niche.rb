# Vinculo do agente (analista) com um Nicho de empresa. Ver CreateUserCompanyNiches.
class UserCompanyNiche < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :company_niche

  validates :company_niche_id, uniqueness: { scope: :user_id }
  validate :same_account

  private

  def same_account
    return if company_niche.nil? || company_niche.account_id == account_id

    errors.add(:company_niche, 'é de outra conta')
  end
end
