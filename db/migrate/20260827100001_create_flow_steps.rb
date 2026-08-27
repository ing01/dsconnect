class CreateFlowSteps < ActiveRecord::Migration[7.2]
  def change
    create_table :flow_steps do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation_flow, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.integer :step_type, null: false, default: 0
      t.text :content
      t.jsonb :options, null: false, default: []
      t.bigint :next_step_id

      t.timestamps
    end

    add_index :flow_steps, %i[conversation_flow_id position]
    add_index :flow_steps, :next_step_id
    add_foreign_key :flow_steps, :flow_steps, column: :next_step_id, on_delete: :nullify
  end
end
