# Quais Categorias o cliente ve ao abrir um chamado.
#
# Categoria e um conceito POR MESA - indice unico em [team_id, name] -, entao as
# mesmas seis ("Duvida", "Erro", "Homologacao"...) existem em cada Mesa. A lista
# que a Area do Cliente mostra e plana, de proposito: ele descreve o PROBLEMA, e
# a Mesa e decisao da triagem. O resultado e que cada nome aparecia uma vez por
# Mesa no select.
#
# A escolha de quais aparecem e configuracao, e nao regra no codigo: e quem
# administra que sabe qual Mesa recebe um "Erro" vindo de fora.
class AddClientVisibleToTicketCategories < ActiveRecord::Migration[7.2]
  def up
    # Desligado por padrao: marcar tudo como visivel manteria a repeticao, que e
    # justamente o que esta coluna existe para resolver.
    add_column :ticket_categories, :client_visible, :boolean, default: false, null: false

    # Deixar todas desligadas daria um select VAZIO ate alguem configurar - pior
    # que o problema. Entao liga uma por nome, a da Mesa mais antiga, que e a
    # candidata mais provavel a ser a de entrada. Quem administra ajusta depois.
    execute <<~SQL.squish
      UPDATE ticket_categories
      SET client_visible = true
      WHERE id IN (
        SELECT DISTINCT ON (c.account_id, c.name) c.id
        FROM (
          SELECT tc.id, tc.name, tc.team_id, t.account_id
          FROM ticket_categories tc
          JOIN teams t ON t.id = tc.team_id
          WHERE t.active
        ) c
        ORDER BY c.account_id, c.name, c.team_id, c.id
      )
    SQL
  end

  def down
    remove_column :ticket_categories, :client_visible
  end
end
