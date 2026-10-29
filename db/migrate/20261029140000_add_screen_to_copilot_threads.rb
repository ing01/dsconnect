# Quando o chat com o DueBot e' aberto fora de uma conversa e de um ticket, guarda
# em qual tela estava (nome da rota). O historico mostra "chat aberto na tela X".
class AddScreenToCopilotThreads < ActiveRecord::Migration[7.0]
  def change
    add_column :copilot_threads, :screen, :string
  end
end
