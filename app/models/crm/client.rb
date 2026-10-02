# Cadastro de cliente/lead do Painel Comercial - DE PROPOSITO separado de
# `Company` (cliente pagante ja implantado): nem todo lead vendido pelo
# comercial chega a assinar contrato, e um registro assim nao deve aparecer
# junto dos clientes de verdade usados no resto do Duedesk.
class Crm::Client < ApplicationRecord
  self.table_name = 'crm_clients'

  belongs_to :account
  has_many :sales, class_name: 'Crm::Sale', foreign_key: 'crm_client_id', dependent: :destroy, inverse_of: :client
  has_many :generated_contracts, class_name: 'Crm::GeneratedContract', foreign_key: 'crm_client_id', dependent: :destroy, inverse_of: :client

  validates :name, presence: true
end
