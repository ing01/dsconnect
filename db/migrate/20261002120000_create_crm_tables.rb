# Painel de CRM Comercial - cadastro de clientes/leads PROPRIO, separado de
# `companies` (ha lead que nunca assina contrato e nao deve entrar no cadastro
# de clientes pagantes). Venda (`crm_sales`) e' sempre de um `crm_client`, com
# varios itens de produto (`crm_sale_items`), igual ao painel standalone atual
# (implantacao/mensalidade por item, somados na venda).
class CreateCrmTables < ActiveRecord::Migration[7.2]
  def change
    create_table :crm_clients do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :cnpj
      t.string :contact_name
      t.string :phone
      t.string :email
      t.text :notes

      t.timestamps
    end
    add_index :crm_clients, :account_id

    create_table :crm_sales do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_client_id, null: false
      t.bigint :user_id
      t.date :competencia, null: false
      t.string :payment_method
      t.integer :installments, default: 1, null: false
      t.string :channel
      t.decimal :implementation_value, precision: 12, scale: 2, default: '0.0', null: false
      t.decimal :monthly_value, precision: 12, scale: 2, default: '0.0', null: false

      t.timestamps
    end
    add_index :crm_sales, :account_id
    add_index :crm_sales, :crm_client_id
    add_index :crm_sales, :user_id

    create_table :crm_sale_items do |t|
      t.bigint :crm_sale_id, null: false
      t.string :product, null: false
      t.decimal :implementation_value, precision: 12, scale: 2, default: '0.0', null: false
      t.decimal :monthly_value, precision: 12, scale: 2, default: '0.0', null: false

      t.timestamps
    end
    add_index :crm_sale_items, :crm_sale_id
  end
end
