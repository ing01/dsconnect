# Cronometro de apontamento: o agente inicia, pausa, continua e, ao finalizar, o
# tempo vira um TicketTimeEntry comum (as horas). Fica numa tabela propria, e nao
# como um apontamento "em andamento", para que os relatorios e totais que somam
# `ticket_time_entries.hours` nunca contem um tempo que ainda esta correndo.
#
# O tempo e' guardado no servidor (`started_at` + `accumulated_seconds`): fechar a
# aba, recarregar ou trocar de aparelho nao perde nem para o relogio.
class CreateTicketTimers < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_timers do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :ticket, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :category, null: false, default: 'implantacao'
      t.text :note
      # Segundos ja acumulados nos trechos anteriores (antes de pausar).
      t.integer :accumulated_seconds, null: false, default: 0
      # Quando o trecho atual comecou; nulo = pausado.
      t.datetime :started_at

      t.timestamps
    end

    # Cada pessoa tem no maximo um cronometro por ticket.
    add_index :ticket_timers, %i[ticket_id user_id], unique: true
    # Achar rapido o que esta correndo (para pausar o anterior ao iniciar outro).
    add_index :ticket_timers, :user_id, where: 'started_at IS NOT NULL', name: 'index_ticket_timers_running_by_user'
  end
end
