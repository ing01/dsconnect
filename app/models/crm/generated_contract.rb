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

  has_one_attached :pdf

  def pdf_url
    return '' unless pdf.attached?

    Rails.application.routes.url_helpers.url_for(pdf)
  end

  def pdf_name
    pdf.attached? ? pdf.filename.to_s : ''
  end
end
