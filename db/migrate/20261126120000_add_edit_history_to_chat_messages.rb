# Editar mensagem do Chat Interno. `edited_at` marca que a mensagem mudou (o
# aviso "Editado" na tela); `edit_history` guarda cada texto anterior, em ordem,
# para quem le poder ver o que estava escrito ("Ver anterior").
class AddEditHistoryToChatMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :chat_messages, :edited_at, :datetime
    add_column :chat_messages, :edit_history, :jsonb, null: false, default: []
  end
end
