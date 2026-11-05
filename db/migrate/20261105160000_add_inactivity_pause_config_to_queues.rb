# Configuracao do fluxo de pausa por inatividade por Fila (mesmas chaves de
# `inboxes.inactivity_config`, ver Inactivity::PauseConfig).
class AddInactivityPauseConfigToQueues < ActiveRecord::Migration[7.2]
  def change
    add_column :queues, :inactivity_pause_config, :jsonb, default: {}, null: false
  end
end
