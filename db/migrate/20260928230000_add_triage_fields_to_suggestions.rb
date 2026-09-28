# Prioridade e Categoria sao listas configuraveis por conta, mesmo espirito de
# SuggestionColumn - so nome e posicao. Tempo gasto e' um numero solto (nao
# precisa de tabela propria). `completed`, na coluna, marca qual e' a coluna
# de "concluido" pra colorir o card e carimbar `completed_at` sozinho quando a
# sugestao entra nela.
class AddTriageFieldsToSuggestions < ActiveRecord::Migration[7.2]
  def change
    create_table :suggestion_priorities do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :suggestion_categories do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_reference :suggestions, :priority, null: true, foreign_key: { to_table: :suggestion_priorities }
    add_reference :suggestions, :category, null: true, foreign_key: { to_table: :suggestion_categories }
    add_column :suggestions, :time_spent_hours, :decimal, precision: 6, scale: 1
    add_column :suggestions, :completed_at, :datetime

    add_column :suggestion_columns, :completed, :boolean, null: false, default: false
  end
end
