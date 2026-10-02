# O SAC: sugestoes, reclamacoes, elogios e pedidos de melhoria que o CLIENTE
# registra pelo Portal.
#
# E uma entidade propria, e nao um Ticket com um tipo diferente: o ticket tem
# Mesa, Estagio, SLA, triagem, complexidade e um fluxo de atendimento inteiro
# que uma reclamacao sobre o comercial nao percorre. Tambem nao e o
# `Suggestion` que ja existe - aquele e o quadro Kanban INTERNO, por usuario,
# sem empresa nem contato.
#
# O caminho de volta para o fluxo normal existe e e explicito: "Converter em
# Ticket" cria o ticket pelo mecanismo de sempre e guarda o vinculo em
# `converted_ticket_id`.
class CreateManifestations < ActiveRecord::Migration[7.2]
  def change
    create_manifestations
    create_messages
    create_activities
    create_attachments
  end

  private

  def create_manifestations
    create_table :manifestations do |t|
      t.references :account, null: false, foreign_key: true
      # Empresa e solicitante sao a FRONTEIRA do que o cliente enxerga, e por isso
      # o MODEL os exige na criacao (`on: :create`).
      #
      # No banco sao nulaveis com `nullify`, seguindo o mesmo acordo que os
      # tickets tem com Company: excluir uma Empresa nunca pode levar o historico
      # de atendimento junto. A manifestacao orfa sai da vista do cliente (o
      # escopo dele filtra por empresa) e continua legivel por dentro.
      t.references :company, null: true, foreign_key: { on_delete: :nullify }
      t.references :contact, null: true, foreign_key: { on_delete: :nullify }
      # Quem responde pelo caso, do lado de dentro. Nulo enquanto ninguem assumiu,
      # e `nullify` para que desligar um agente nao apague a manifestacao.
      t.references :assignee, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      # O numero que o cliente cita ao falar com a equipe. Sequencial por conta,
      # como o `display_id` do ticket.
      t.integer :display_id, null: false

      t.integer :kind, null: false, default: 0
      t.integer :subject_area, null: false, default: 0
      t.integer :status, null: false, default: 0

      t.string :title, null: false
      t.text :description, null: false

      # O ticket gerado pela conversao. Presente = ja foi convertida, e e isso
      # que impede converter duas vezes.
      t.references :converted_ticket, null: true,
                                      foreign_key: { to_table: :tickets, on_delete: :nullify }
      t.datetime :converted_at

      t.timestamps
    end

    # O numero e unico DENTRO da conta - duas contas podem ter a manifestacao 1.
    add_index :manifestations, [:account_id, :display_id], unique: true
    # Os recortes que as duas telas fazem: a do cliente por empresa, a interna
    # por status.
    add_index :manifestations, [:account_id, :status]
    add_index :manifestations, [:company_id, :created_at]
  end

  def create_messages
    # A conversa e as anotacoes, numa tabela so.
    #
    # O modulo de Tickets separa publico e interno em duas tabelas, mas por um
    # motivo que aqui nao existe: a tabela publica de la entrega e-mail. Sem
    # entrega, `visibility` com um scope resolve - e o controller do cliente le
    # SOMENTE esse scope.
    create_table :manifestation_messages do |t|
      t.references :manifestation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      # Autor: o agente OU o contato, nunca os dois. Ambos nulaveis para que
      # remover quem escreveu nao apague o que foi dito.
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.references :contact, null: true, foreign_key: { on_delete: :nullify }

      # 0 = resposta visivel ao cliente; 1 = anotacao interna.
      t.integer :visibility, null: false, default: 0
      t.text :body, null: false

      t.timestamps
    end

    add_index :manifestation_messages, [:manifestation_id, :created_at],
              name: 'index_manifestation_messages_on_manifestation_and_date'
  end

  def create_activities
    # O historico de movimentacoes, no mesmo formato do TicketActivity: tipo,
    # antes/depois e `meta` para o que nao cabe em duas strings.
    create_table :manifestation_activities do |t|
      t.references :manifestation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.references :contact, null: true, foreign_key: { on_delete: :nullify }

      t.integer :activity_type, null: false
      t.string :previous_value
      t.string :new_value
      t.jsonb :meta, default: {}

      t.timestamps
    end

    add_index :manifestation_activities, [:manifestation_id, :created_at],
              name: 'index_manifestation_activities_on_manifestation_and_date'
  end

  def create_attachments
    # Os arquivos. Tabela propria porque `ticket_attachments.ticket_id` e
    # obrigatorio - nao ha como pendurar nela um anexo que ainda nao e de ticket.
    create_table :manifestation_attachments do |t|
      t.references :manifestation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.references :contact, null: true, foreign_key: { on_delete: :nullify }

      t.timestamps
    end
  end
end
