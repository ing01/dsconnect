class CreateQueues < ActiveRecord::Migration[7.2]
  def change
    create_table :queues do |t|
      t.references :account, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false
      t.integer :distribution_strategy, default: 0, null: false
      t.integer :priority_boost
      t.bigint :default_sla_policy_id

      t.timestamps
    end

    add_index :queues, %i[account_id name], unique: true
    add_index :queues, :default_sla_policy_id
    add_foreign_key :queues, :sla_policies, column: :default_sla_policy_id
  end
end
