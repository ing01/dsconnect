# Auditoria dos relogios, espelhando SlaEvent das Conversations. O historico do
# Ticket (TicketActivity) continua sendo a linha do tempo que o usuario le; isto
# aqui e o registro de SLA propriamente dito, do qual os relatorios futuros
# saem sem varrer atividades.
#
# `meta` guarda quem cumpriu, por qual origem e qual registro relacionado -
# a comunicacao do ticket ou a mensagem da conversa.
class CreateTicketSlaEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :ticket_sla_events do |t|
      t.references :account, null: false, index: true
      t.references :ticket, null: false, index: false
      t.references :ticket_applied_sla, null: false, index: true
      t.references :user, null: true, index: true

      t.integer :event_type, null: false
      t.jsonb :meta, default: {}

      t.timestamps
    end

    add_index :ticket_sla_events, %i[ticket_id created_at]
  end
end
