# Lista de Subnichos das Empresas - mesmo padrao de CompanyNiche (lista por
# conta, criada livremente na importacao/tela, sem CRUD completo de proposito).
class CompanySubNiche < ApplicationRecord
  belongs_to :account
  has_many :companies, dependent: :nullify
  has_many :user_company_sub_niches, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :account_id }

  scope :ordered_by_name, -> { order(:name) }
end
