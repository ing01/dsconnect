class CreateConversationFlowStates < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_flow_states do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true, index: { unique: true }
      t.references :conversation_flow, null: false, foreign_key: true
      t.bigint :current_step_id
      t.integer :status, null: false, default: 0
      t.integer :retry_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :conversation_flow_states, :current_step_id
    add_foreign_key :conversation_flow_states, :flow_steps, column: :current_step_id, on_delete: :nullify
  end
end
