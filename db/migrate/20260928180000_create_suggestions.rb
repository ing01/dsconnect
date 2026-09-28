# Quadro de Sugestoes de melhoria: 1 quadro Kanban por conta (nao por Time,
# diferente do quadro de Tickets), com colunas configuraveis
# (SuggestionColumn - nome + posicao, sem os campos especificos de Ticket
# como SLA/categoria/automacao).
class CreateSuggestions < ActiveRecord::Migration[7.2]
  def change
    create_table :suggestion_columns do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :suggestions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :suggestion_column, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
