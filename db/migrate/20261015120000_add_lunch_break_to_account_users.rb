class AddLunchBreakToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    # Nulo = agente sem horario de almoco cadastrado (nao entra em nenhuma
    # regra de bloqueio). Hora/minuto em colunas separadas, no mesmo molde do
    # `WorkingHour` (open_hour/open_minutes/close_hour/close_minutes) - mesma
    # ideia de janela, sem reaproveitar aquela tabela porque ela pertence a
    # Inbox/Mesa, nunca a um agente.
    add_column :account_users, :lunch_start_hour, :integer
    add_column :account_users, :lunch_start_minutes, :integer
    add_column :account_users, :lunch_end_hour, :integer
    add_column :account_users, :lunch_end_minutes, :integer
  end
end
