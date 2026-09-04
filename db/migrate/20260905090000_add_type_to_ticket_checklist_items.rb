class AddTypeToTicketChecklistItems < ActiveRecord::Migration[7.2]
  def change
    change_table :ticket_checklist_items, bulk: true do |t|
      t.string :item_type, default: 'checkbox', null: false
      t.boolean :required, default: false, null: false
      t.jsonb :options, default: [], null: false
      t.text :value
    end
  end
end
