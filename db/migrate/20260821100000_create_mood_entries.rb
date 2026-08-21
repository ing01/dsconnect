class CreateMoodEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :mood_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :mood, null: false
      t.date :entry_date, null: false

      t.timestamps
    end

    add_index :mood_entries, [:account_id, :user_id, :entry_date], unique: true, name: 'uniq_mood_entry_per_user_per_day'
  end
end
