class AddBlockedByChildToTickets < ActiveRecord::Migration[7.2]
  # Impedimento que o PAI recebeu de um ticket FILHO: guarda de qual filho veio, para
  # que retirar o impedimento do filho retire o do pai (e so' o que veio dele). Nulo
  # quando o impedimento e' do proprio ticket.
  def change
    add_column :tickets, :blocked_by_child_id, :bigint
    add_index :tickets, :blocked_by_child_id, where: 'blocked_by_child_id IS NOT NULL'
    add_foreign_key :tickets, :tickets, column: :blocked_by_child_id, on_delete: :nullify
  end
end
