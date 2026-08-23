class CreateTicketActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_activities do |t|
      t.references :account, null: false, index: true
      t.references :ticket, null: false, index: true
      t.references :user, null: true, index: true # nil = system/automation
      t.integer :activity_type, null: false
      t.string :previous_value
      t.string :new_value
      t.jsonb :meta, default: {}

      t.timestamps
    end

    add_index :ticket_activities, [:ticket_id, :created_at]
  end
end
