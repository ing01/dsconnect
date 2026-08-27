# Uma extensao passa a dizer qual dos tres prazos esticou. As linhas que ja
# existem sao de quando havia um unico prazo por ticket, que vira o relogio de
# solucao - vide MigrateTicketDueAtToResolutionSla.
class AddSlaKindToTicketSlaExtensions < ActiveRecord::Migration[7.0]
  def change
    add_reference :ticket_sla_extensions, :ticket_applied_sla, null: true, index: true
    add_column :ticket_sla_extensions, :sla_kind, :integer
  end
end
