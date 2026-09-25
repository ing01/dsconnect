# Guarda a chave/numero do card no Jira (ou sistema equivalente) quando o
# ticket vem de uma importacao (Tickets::ImportService, coluna
# "Desenvolvimento" da planilha) - mostrado na aba "Desenvolvimento" do
# detalhe do ticket (TicketDevelopmentTab.vue).
class AddJiraKeyToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :jira_key, :string
  end
end
