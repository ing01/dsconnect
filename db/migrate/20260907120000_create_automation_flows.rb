# A camada de fluxo das automacoes.
#
# A regra em si continua sendo a AutomationRule que ja existia: gatilho,
# condicoes, nome, ativo. O que se acrescenta e o fluxo (as etapas) e o estado
# de cada execucao - que e o que hoje nao existe, porque uma automacao comum
# roda e termina no mesmo instante, sem esperar resposta de ninguem.
class CreateAutomationFlows < ActiveRecord::Migration[7.2]
  def change
    add_flow_to_rules
    create_runs
    create_run_events
  end

  def add_flow_to_rules
    # O grafo de etapas vive na propria regra: o editor grava o fluxo inteiro de
    # uma vez e nada consulta uma etapa isolada, entao uma tabela a parte so
    # acrescentaria junção sem responder pergunta nenhuma.
    add_column :automation_rules, :flow_steps, :jsonb, default: [], null: false
  end

  def create_runs
    # Uma execucao do fluxo sobre uma conversa. Diferente da regra comum, esta
    # sobrevive entre mensagens: e ela que sabe em que etapa parou e o que ja
    # coletou do cliente.
    create_table :automation_flow_runs do |t|
      t.references :account, null: false, index: true
      t.references :automation_rule, null: false, index: true
      t.references :conversation, null: false, index: true
      # Preenchido quando o fluxo chega a criar o ticket.
      t.references :ticket, null: true, index: true

      t.integer :status, null: false, default: 0
      t.string :current_step_id
      # O que foi coletado: respostas do cliente e o que as buscas acharam.
      t.jsonb :variables, null: false, default: {}
      # Ate quando vale esperar a resposta do cliente.
      t.datetime :waiting_until
      t.text :last_error

      t.timestamps
    end

    # Uma conversa nao pode ter duas execucoes vivas da mesma automacao - seria
    # o bot perguntando duas vezes a mesma coisa.
    add_index :automation_flow_runs, [:conversation_id, :automation_rule_id],
              unique: true, where: 'status IN (0, 1)',
              name: 'index_automation_flow_runs_on_live_run'
    # Para a varredura de expirados.
    add_index :automation_flow_runs, :waiting_until, where: 'status = 1'
  end

  def create_run_events
    # O historico pedido: uma linha por etapa executada, com o que entrou, o que
    # saiu e o erro quando houve.
    create_table :automation_flow_run_events do |t|
      t.references :account, null: false, index: true
      t.references :automation_flow_run, null: false, index: { name: 'index_flow_run_events_on_run' }

      t.string :step_id
      t.string :step_type
      t.integer :outcome, null: false, default: 0
      t.jsonb :input, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.text :error

      t.datetime :created_at, null: false
    end

    add_index :automation_flow_run_events, [:automation_flow_run_id, :created_at],
              name: 'index_flow_run_events_on_run_and_time'
  end
end
