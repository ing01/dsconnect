# Roteamento automatico do ticket aberto pelo Portal do Cliente, por nivel de
# prioridade da Empresa (client_level: 1 Baixa, 2 Media, 3 Alta) - uma Mesa
# especifica por nivel, quando configurada.
class CreateTicketRoutingRules < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_routing_rules do |t|
      t.bigint :account_id, null: false
      t.integer :client_level, null: false
      t.bigint :team_id, null: false

      t.timestamps
    end

    add_index :ticket_routing_rules, :account_id
    add_index :ticket_routing_rules, [:account_id, :client_level], unique: true
  end
end
