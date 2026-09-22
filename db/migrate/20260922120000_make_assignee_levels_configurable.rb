# Quantos niveis a Mesa usa passa a ser configuracao, e nao codigo.
#
# A primeira versao dos niveis nasceu com dois fixos: `assignee_2_id` no ticket e
# a lista `[1, 2]` no codigo. O comentario de lá dizia que um Nivel 3 seria "so
# mais um numero", o que nao era verdade - `AssigneeLeveled.assignee_column`
# mandava todo nivel diferente de 1 para `assignee_2_id`, entao um Nivel 3
# gravaria em cima do Nivel 2, sem erro nenhum.
#
# Duas mudancas resolvem: a Mesa passa a dizer QUANTOS niveis usa, e o ticket
# ganha de uma vez as colunas ate o teto. Assim ligar o Nivel 3 (ou o 4, ou o 5)
# e mexer numa tela, nao pedir migracao.
class MakeAssigneeLevelsConfigurable < ActiveRecord::Migration[7.2]
  # O teto. Nao ha Mesa de suporte com mais de cinco niveis, e um teto conhecido
  # e o que permite colunas nomeadas - mais baratas de ler e de indexar do que
  # uma tabela de ligacao consultada em toda listagem do Kanban.
  MAX_LEVEL = 5

  def change
    # Quantos niveis esta Mesa usa. Dois por padrao: e o que as Mesas que ja
    # ligaram a configuracao tem hoje, entao nenhuma muda de comportamento.
    add_column :teams, :assignee_levels_count, :integer, default: 2, null: false

    # Do 3 ao teto. O Nivel 1 e o `assignee_id` de sempre e o 2 ja existe.
    #
    # Indice parcial: a coluna e nula na esmagadora maioria dos tickets, e o
    # indice existe para responder "os tickets em que sou o Nivel N", nunca para
    # varrer os nulos.
    (3..MAX_LEVEL).each do |level|
      add_reference :tickets, :"assignee_#{level}", foreign_key: { to_table: :users }, null: true, index: false
      add_index :tickets, :"assignee_#{level}_id", where: "assignee_#{level}_id IS NOT NULL"
    end
  end
end
