class CreateTicketProposals < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_proposals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      # Nulo quando o autor sai da conta: a proposta enviada ao cliente permanece.
      t.references :user, foreign_key: { on_delete: :nullify }
      # Os dados da empresa sao gravados NA proposta, e nao lidos da Empresa na
      # hora de gerar o PDF: o documento que o cliente aprovou nao pode mudar
      # porque o cadastro mudou depois.
      t.string :company_name, null: false
      t.string :company_cnpj
      t.string :company_address
      t.text :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :proposal_date, null: false
      t.date :valid_until, null: false
      t.string :location, null: false
      t.text :payment_terms, null: false
      t.integer :deadline_days, null: false
      t.string :signer_name
      t.boolean :visible_to_client, null: false, default: false
      t.string :status, null: false, default: 'pending'
      t.datetime :decided_at
      t.references :decided_by_contact, foreign_key: { to_table: :contacts, on_delete: :nullify }
      t.timestamps
    end
  end
end
