# Niveis de responsavel por Mesa de Servico.
#
# A Mesa de Suporte atende em dois niveis: o Nivel 1 faz a triagem e o contato
# inicial, o Nivel 2 recebe o que foi escalado. O sistema precisa saber quem
# atuou em cada nivel e quanto tempo cada um gastou.
#
# Nada disso vale para Mesas que nao ligarem a configuracao: sem ela o ticket
# segue com um responsavel so, exatamente como hoje.
class AddAssigneeLevels < ActiveRecord::Migration[7.2]
  def change
    # A chave da Mesa. Desligada por padrao para nao mudar nenhuma Mesa que ja
    # existe.
    add_column :teams, :assignee_levels_enabled, :boolean, default: false, null: false

    # Em quais niveis este membro pode atuar. Array porque a mesma pessoa pode
    # atender nos dois, e porque um Nivel 3 no futuro e so mais um numero - nao
    # uma coluna nova.
    add_column :team_members, :levels, :integer, array: true, default: [], null: false

    # O Nivel 2. O `assignee_id` que ja existe continua sendo o Nivel 1: e o
    # campo que a policy, os filtros, o "assumir ticket" e a exportacao ja
    # usam, e reinterpretar em vez de substituir mantem tudo isso funcionando.
    add_reference :tickets, :assignee_2, foreign_key: { to_table: :users }, null: true, index: true

    # Em que nivel o apontamento foi feito. Gravado na hora, e nao deduzido
    # depois: se o responsavel mudar, o que ja foi apontado continua pertencendo
    # a quem apontou, no nivel em que estava.
    add_column :ticket_time_entries, :level, :integer

    add_index :ticket_time_entries, [:ticket_id, :level]
    add_index :ticket_time_entries, [:account_id, :worked_on]
  end
end
