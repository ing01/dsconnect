# Trava de ordem da fila: quando ligada para um agente, ele so pode pegar a
# proxima conversa da fila (por prioridade, depois mais antiga) - nunca
# escolher livremente. Administrador nunca e afetado por isso (checado no
# controller, nao aqui).
class AddEnforceQueueOrderToAccountUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :account_users, :enforce_queue_order, :boolean, default: false, null: false
  end
end
