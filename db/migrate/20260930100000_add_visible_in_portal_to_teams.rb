# Nenhuma Mesa aparece no Portal do Cliente ate alguem marcar - as ja
# existentes continuam ocultas de proposito (`default: false`), pra Ingrid
# escolher com calma quais quer expor em vez de tudo ja virar visivel sozinho.
class AddVisibleInPortalToTeams < ActiveRecord::Migration[7.2]
  def change
    add_column :teams, :visible_in_portal, :boolean, default: false, null: false
  end
end
