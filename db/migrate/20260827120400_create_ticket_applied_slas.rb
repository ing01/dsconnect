# Um relogio de SLA do Ticket. Tres tipos - atendimento, estagio e solucao -
# com estado proprio cada um, e nao um boolean global.
#
# Diferente de AppliedSla (Conversation), que recalcula os vencimentos na hora
# a partir da conversa, aqui o `due_at` e persistido: o relogio de estagio conta
# a partir da entrada naquela coluna especifica, e as horas adicionadas precisam
# deslocar um prazo que exista de fato.
#
# `threshold` e `only_during_business_hours` sao copiados da configuracao no
# momento em que o relogio comeca, para que mudar a matriz da Mesa depois nao
# reescreva o passado.
class CreateTicketAppliedSlas < ActiveRecord::Migration[7.0]
  def change
    create_table :ticket_applied_slas do |t|
      t.references :account, null: false, index: true
      t.references :ticket, null: false, index: false
      # Preenchido apenas nos relogios de estagio.
      t.references :ticket_column, null: true, index: true
      t.references :ticket_sla_policy, null: true, index: true

      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.float :threshold, null: false
      t.boolean :only_during_business_hours, null: false, default: false

      t.datetime :started_at, null: false
      t.datetime :due_at, null: false
      t.datetime :completed_at
      # Segundos concedidos manualmente, somados ao prazo. Guardado a parte do
      # threshold para que relatorio consiga separar prazo contratado de folga
      # concedida.
      t.float :extended_seconds, null: false, default: 0

      t.timestamps
    end

    add_clock_indexes
  end

  private

  def add_clock_indexes
    add_index :ticket_applied_slas, %i[ticket_id kind]
    # Um unico relogio ativo por tipo. Linhas encerradas ficam quantas forem
    # precisas - e o que permite o historico por estagio e, no futuro, novos
    # ciclos de atendimento a cada mensagem do cliente.
    add_index :ticket_applied_slas, %i[ticket_id kind], unique: true,
                                                        where: 'status = 0',
                                                        name: 'index_ticket_applied_slas_one_active_per_kind'
    # Varredura de vencimentos: so os relogios ainda correndo interessam.
    add_index :ticket_applied_slas, %i[account_id due_at], where: 'status = 0',
                                                           name: 'index_ticket_applied_slas_active_due_at'
  end
end
