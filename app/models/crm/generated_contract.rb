# PDF de contrato gerado a partir de um `Crm::ContractTemplate` + os dados
# preenchidos na hora (ver `Crm::Contracts::GenerationService`). `data` guarda
# os valores usados, para reimprimir/conferir depois sem depender do estado
# atual do cadastro do cliente.
class Crm::GeneratedContract < ApplicationRecord
  self.table_name = 'crm_generated_contracts'

  belongs_to :account
  belongs_to :template, class_name: 'Crm::ContractTemplate', foreign_key: 'crm_contract_template_id', inverse_of: :generated_contracts
  belongs_to :client, class_name: 'Crm::Client', foreign_key: 'crm_client_id', inverse_of: :generated_contracts
  belongs_to :sale, class_name: 'Crm::Sale', foreign_key: 'crm_sale_id', optional: true

  has_many :revisions, class_name: 'Crm::GeneratedContractRevision', foreign_key: 'crm_generated_contract_id',
                       dependent: :destroy, inverse_of: :generated_contract

  has_one_attached :pdf
  # Guarda tambem o .docx preenchido (so' com o primeiro representante) para
  # a Ingrid abrir no Word e acrescentar a mao os demais representantes,
  # quando o cliente tiver mais de um (ver `Crm::Client#extra_representatives`).
  has_one_attached :docx

  def pdf_url
    return '' unless pdf.attached?

    Rails.application.routes.url_helpers.url_for(pdf)
  end

  def pdf_name
    pdf.attached? ? pdf.filename.to_s : ''
  end

  def docx_url
    return '' unless docx.attached?

    Rails.application.routes.url_helpers.url_for(docx)
  end

  def docx_name
    docx.attached? ? docx.filename.to_s : ''
  end
end
