# Automacao de Estagio: uma lista de acoes (TicketColumn::AUTOMATION_ACTION_TYPES)
# que roda sozinha sempre que um ticket ENTRA nesta coluna - "quando cair em
# Finalizado, muda a prioridade, fecha o ticket, etc" (Configuracoes >
# Estagios). Ver TicketColumnAutomationListener e Tickets::ColumnAutomationService.
class AddAutomationToTicketColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_columns, :automation_actions, :jsonb, default: [], null: false
    add_column :ticket_columns, :automations_enabled, :boolean, default: true, null: false
  end
end
