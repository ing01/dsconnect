# A Complexidade do ticket.
#
# Lista da CONTA, e nao da Mesa - mesmo espirito de ServiceCatalog. "Baixo",
# "Medio" e "Alto" sao os mesmos nomes em toda a empresa; o que varia e quais
# deles cada Mesa oferece, e isso mora na juncao `ticket_complexity_teams`. Uma
# lista por Mesa (como TicketCategory) obrigaria a recadastrar os mesmos tres
# nomes em cada Mesa e tornaria impossivel comparar ticket de Mesas diferentes.
#
# `active` desliga o nivel em TODA a conta, sem apagar: a Complexidade fica em
# tickets antigos, e apagar perderia o dado. A juncao decide disponibilidade por
# Mesa; `active` decide se ela existe.
#
# `ticket_complexity_id` no ticket e NULO de proposito: todo ticket que ja existe
# continua valido sem Complexidade. A exigencia aparece so no fechamento, e so
# quando a Mesa tem alguma Complexidade para oferecer (ver TicketClosing).
#
# A coluna `weight` existe para o calculo de custo por cliente que vem depois.
# Nao e lida por nada nesta etapa - esta aqui para que a etapa seguinte nao
# precise de outra migracao sobre a mesma tabela.
class CreateTicketComplexities < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_complexities do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      # Peso relativo do nivel, para o custo por cliente da etapa futura.
      t.decimal :weight, precision: 8, scale: 2
      t.timestamps
    end

    # Nome unico por conta: dois "Alto" na mesma lista nao teriam como ser
    # distinguidos por quem escolhe no formulario.
    add_index :ticket_complexities, [:account_id, :name], unique: true
    add_index :ticket_complexities, [:account_id, :position]

    # A matriz Complexidade x Mesa. Sem linha, a Mesa nao oferece aquele nivel.
    create_table :ticket_complexity_teams do |t|
      t.references :ticket_complexity, null: false, foreign_key: true, index: false
      t.references :team, null: false, foreign_key: true
      t.timestamps
    end

    add_index :ticket_complexity_teams, [:ticket_complexity_id, :team_id],
              unique: true, name: 'index_ticket_complexity_teams_unique'

    # `nullify` no banco tambem, e nao so no model: apagar uma Complexidade nunca
    # pode derrubar um ticket que a usava.
    add_reference :tickets, :ticket_complexity, null: true,
                                                foreign_key: { to_table: :ticket_complexities, on_delete: :nullify }
  end
end
