# == Schema Information
#
# Table name: company_contacts
#
#  id         :bigint           not null, primary key
#  contact_id :bigint           not null
#  company_id :bigint           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class CompanyContact < ApplicationRecord
  belongs_to :contact
  belongs_to :company

  # O vinculo com a Empresa costuma nascer DEPOIS do contato (importacao de
  # solicitantes, vinculo pela tela): e' agora que ele passa a ser um solicitante
  # e, se tem e-mail e ainda nao tem credencial, recebe a senha padrao.
  after_create_commit :provision_contact_client_access

  private

  def provision_contact_client_access
    contact.provision_default_client_access!
  end
end
