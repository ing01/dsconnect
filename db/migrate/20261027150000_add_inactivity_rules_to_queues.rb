# Aviso e encerramento por inatividade do chat do Portal/app, configurados por
# Fila. Os tempos sao em minutos: o encerramento conta a partir do aviso (ou da
# ultima mensagem da equipe, se a Fila nao tiver aviso).
class AddInactivityRulesToQueues < ActiveRecord::Migration[7.2]
  def change
    add_column :queues, :inactivity_nudge_after, :integer
    add_column :queues, :inactivity_nudge_message, :text
    add_column :queues, :inactivity_close_after, :integer
    add_column :queues, :inactivity_close_message, :text
  end
end
