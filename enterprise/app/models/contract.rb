# == Schema Information
#
# Table name: contracts
#
#  id                     :bigint           not null, primary key
#  contract_type          :string
#  total_value            :decimal(12, 2)
#  total_value_mode       :string           default("auto"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  responsible_contact_id :integer
#
class Contract < ApplicationRecord
  TOTAL_VALUE_MODES = %w[auto manual].freeze

  belongs_to :account
  belongs_to :responsible_contact, class_name: 'Contact', optional: true
  has_many :contract_products, -> { includes(:product) }, dependent: :destroy, autosave: true
  # `dependent: :nullify` - apagar um Contrato nao pode levar Empresas junto,
  # so desvincula-las (elas voltam a ter cobranca manual, como antes de terem
  # um contrato).
  has_many :companies, dependent: :nullify

  accepts_nested_attributes_for :contract_products, allow_destroy: true

  validates :contract_type, inclusion: { in: Company::BILLING_TYPES }, allow_blank: true
  validates :total_value_mode, inclusion: { in: TOTAL_VALUE_MODES }
  validates :total_value, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  scope :search_by_participant_or_responsible, lambda { |query|
    left_joins(:companies, :responsible_contact)
      .where('companies.name ILIKE :search OR contacts.name ILIKE :search', search: "%#{query.strip}%")
      .distinct
  }

  # Substitui o conjunto de Empresas participantes por `ids` - cada mudanca
  # passa por `Company#update!` (nao `update_all`) pra disparar
  # `sync_billing_from_contract` nos dois sentidos: quem entra recebe o valor
  # do contrato, quem sai volta a ter cobranca manual.
  def sync_companies!(ids)
    target_ids = Array(ids).map(&:to_i).to_set
    companies.where.not(id: target_ids.to_a).find_each { |company| company.update!(contract_id: nil) }
    account.companies.where(id: target_ids.to_a).find_each { |company| company.update!(contract_id: id) }
  end

  # Soma das linhas de produto (padrao), a menos que o valor tenha sido
  # sobrescrito manualmente - e' o que alimenta `billing_amount` de cada
  # Empresa vinculada quando o contrato e' selecionado (ver `Company#sync_billing_from_contract`).
  def computed_total_value
    return total_value.to_d if total_value_mode == 'manual' && total_value.present?

    contract_products.sum(&:subtotal)
  end
end
