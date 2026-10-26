# A tabela em si ja entra nesta fase (a FK de tickets.sprint_id depende dela),
# mas o model/UI completos (CRUD, Backlog, Sprint ativo) sao da Fase 2 do
# modulo de desenvolvimento - ver o plano.
class CreateSprints < ActiveRecord::Migration[7.1]
  def change
    create_table :sprints do |t|
      t.references :account, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.integer :status, null: false, default: 0 # upcoming/active/completed

      t.timestamps
    end
    add_index :sprints, [:team_id, :status]
  end
end
