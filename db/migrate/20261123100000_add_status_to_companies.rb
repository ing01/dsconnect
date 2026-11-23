# Situacao do cliente: 'active' (Ativo) ou 'inactive' (Inativo). Todo cliente que
# ja existe entra como Ativo (pedido da Ingrid, 2026-11-23) - o default da coluna
# cuida disso sem precisar reescrever as linhas uma a uma em tabela grande.
class AddStatusToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_column :companies, :status, :string, null: false, default: 'active'
    add_index :companies, [:account_id, :status]
  end
end
