# Lista de Nichos das Empresas - mesmo padrao de CompanyCategory (lista por
# conta, criada livremente na tela, sem CRUD completo de proposito).
class CompanyNiche < ApplicationRecord
  belongs_to :account
  has_many :companies, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :account_id }

  scope :ordered_by_name, -> { order(:name) }
end
