# De onde a pessoa abriu a conversa com o DueBot: numa Conversa ou num Ticket.
# O historico usa isso para mostrar "chat aberto na conversa #X" / "no ticket
# #X" com um link de volta. Sao so' referencias (sem FK): apagar a conversa ou
# o ticket nao pode apagar o historico do DueBot.
class AddContextToCopilotThreads < ActiveRecord::Migration[7.0]
  def change
    add_column :copilot_threads, :conversation_display_id, :integer
    add_column :copilot_threads, :ticket_id, :bigint
  end
end
