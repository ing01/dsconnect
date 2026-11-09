# Tres campos novos e INDEPENDENTES dos ja existentes (pedido da Ingrid,
# 2026-11-09): `classification_level` e manual (1 a 5, sem relacao com
# `client_level`, que continua automatico a partir da mensalidade - ver
# Company#compute_client_level); `company_niche` e' uma segunda lista de
# opcoes com criacao livre, separada de `company_category`; `specialist' e'
# o agente responsavel pela Empresa.
class AddClassificationNicheAndSpecialistToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_column :companies, :classification_level, :integer
    add_reference :companies, :company_niche, foreign_key: true, index: true
    add_reference :companies, :specialist, foreign_key: { to_table: :users }, index: true
  end
end
