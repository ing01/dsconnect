class CreateConversationFlows < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_flows do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :conversation_flows, %i[account_id name], unique: true
  end
end
