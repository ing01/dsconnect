# Quem esta cuidando da sugestao/melhoria - so Administradores podem ser
# responsaveis (validado no model), pra ficar visivel quem esta produzindo o
# que, sem virar mais um campo de atribuicao livre pra qualquer agente.
class AddAssigneeToSuggestions < ActiveRecord::Migration[7.2]
  def change
    add_reference :suggestions, :assignee, null: true, foreign_key: { to_table: :users }
  end
end
