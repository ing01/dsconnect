# Modelo de contrato (.docx) do Painel Comercial, com marcadores `[[token]]`
# no texto. `tokens` e' preenchido automaticamente ao anexar o arquivo (ver
# `Crm::Contracts::TokenExtractorService`), e alimenta o formulario de
# geracao (um campo por token encontrado no modelo).
class Crm::ContractTemplate < ApplicationRecord
  self.table_name = 'crm_contract_templates'

  belongs_to :account
  has_one_attached :file
  has_many :generated_contracts, class_name: 'Crm::GeneratedContract',
                                  foreign_key: 'crm_contract_template_id', dependent: :destroy, inverse_of: :template

  validates :name, presence: true

  def file_url
    return '' unless file.attached?

    Rails.application.routes.url_helpers.url_for(file)
  end

  def file_name
    file.attached? ? file.filename.to_s : ''
  end

  # Chamado explicitamente pelo controller logo apos `file.attach` (ActiveStorage
  # nao dispara callback de model quando so o attachment muda).
  def extract_tokens!
    return unless file.attached?

    file.blob.open do |tmp_file|
      update_column(:tokens, Crm::Contracts::TokenExtractorService.new(tmp_file.path).perform) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
