# Aviso e encerramento por inatividade, e mensagem de encerramento, por caixa de
# entrada (Portal do Cliente e WhatsApp). Chaves de `inactivity_config`:
# nudge_after (min), inactivity_message (aviso), close_after (min, depois do
# aviso) e resolve_message (encerramento, manual ou por inatividade).
class AddInactivityConfigToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :inboxes, :inactivity_config, :jsonb, default: {}, null: false
  end
end
