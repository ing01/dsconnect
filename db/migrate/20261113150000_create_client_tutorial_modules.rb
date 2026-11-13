class CreateClientTutorialModules < ActiveRecord::Migration[7.0]
  def change
    # Os "modulos" da aba Tutoriais (DS Connect, DS Comercial...): cada um vira um
    # card que, ao clicar, abre os videos que estao dentro dele.
    create_table :client_tutorial_modules do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    # Opcional: tutorial sem modulo aparece no card "Geral". Apagar o modulo solta
    # os videos (nullify) em vez de apaga-los.
    add_reference :client_tutorials, :client_tutorial_module, foreign_key: { on_delete: :nullify }, null: true
  end
end
