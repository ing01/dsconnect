# A versao de um Crm::GeneratedContract ANTES de ser regenerado (ver
# Crm::Contracts::RegenerationService) - guarda o `data` e os arquivos que
# estavam em vigor, para a Ingrid conseguir baixar o contrato com o
# representante antigo mesmo depois de uma troca de representante.
class Crm::GeneratedContractRevision < ApplicationRecord
  self.table_name = 'crm_generated_contract_revisions'

  belongs_to :account
  belongs_to :generated_contract, class_name: 'Crm::GeneratedContract', foreign_key: 'crm_generated_contract_id',
                                  inverse_of: :revisions

  has_one_attached :pdf
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
