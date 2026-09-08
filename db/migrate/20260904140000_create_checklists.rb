class CreateChecklists < ActiveRecord::Migration[7.2]
  class MigrationProjectTaskTemplate < ActiveRecord::Base
    self.table_name = 'project_task_templates'
  end

  class MigrationChecklist < ActiveRecord::Base
    self.table_name = 'checklists'
  end

  def up
    create_table :checklists do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.jsonb :items, default: [], null: false

      t.timestamps
    end

    add_reference :project_task_templates, :checklist, foreign_key: true, index: true

    backfill_checklists_from_task_templates!

    remove_column :project_task_templates, :checklist
  end

  def down
    add_column :project_task_templates, :checklist, :jsonb, default: [], null: false
    remove_reference :project_task_templates, :checklist, foreign_key: true
    drop_table :checklists
  end

  private

  # Every ProjectTaskTemplate that already had inline checklist items gets its
  # own Checklist record carrying those same items, so tasks configured before
  # this migration keep working exactly as before - just pointed at a
  # (reusable) Checklist instead of an embedded jsonb array.
  def backfill_checklists_from_task_templates!
    MigrationProjectTaskTemplate.find_each do |template|
      items = template.checklist
      next if items.blank?

      checklist = MigrationChecklist.create!(account_id: template.account_id, name: "#{template.name} - Checklist", items: items)
      template.update_column(:checklist_id, checklist.id) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
