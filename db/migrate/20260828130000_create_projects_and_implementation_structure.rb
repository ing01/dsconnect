class CreateProjectsAndImplementationStructure < ActiveRecord::Migration[7.2]
  def change
    create_table :project_task_templates do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :default_ticket_title, null: false
      t.text :description
      t.references :default_assignee, foreign_key: { to_table: :users }, index: true
      t.integer :due_days, default: 1, null: false
      t.string :next_project_stage
      t.jsonb :checklist, default: [], null: false

      t.timestamps
    end

    create_table :project_modules do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    create_table :project_module_task_templates do |t|
      t.references :project_module, null: false, foreign_key: true, index: true
      t.references :project_task_template, null: false, foreign_key: true, index: true
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    add_index :project_module_task_templates, [:project_module_id, :project_task_template_id],
              unique: true, name: 'index_module_task_templates_uniqueness'

    create_table :projects do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.references :company, foreign_key: true, index: true
      t.references :contact, foreign_key: true, index: true
      t.references :team, null: false, foreign_key: true, index: true
      t.references :project_module, foreign_key: true, index: true
      t.string :stage, default: 'pendente', null: false
      t.integer :status, default: 0, null: false
      t.date :start_date
      t.date :due_date
      t.jsonb :custom_attributes, default: {}, null: false

      t.timestamps
    end
    add_index :projects, [:account_id, :stage]
    add_index :projects, [:account_id, :status]

    create_table :ticket_checklist_items do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :ticket, null: false, foreign_key: true, index: true
      t.string :title, null: false
      t.boolean :completed, default: false, null: false
      t.datetime :completed_at
      t.references :completed_by, foreign_key: { to_table: :users }, index: true
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    add_index :ticket_checklist_items, [:ticket_id, :completed]

    change_table :tickets, bulk: true do |t|
      t.references :project, foreign_key: true, index: true
      t.references :project_task_template, foreign_key: true, index: true
      t.datetime :due_date
      t.datetime :scheduled_at
      t.string :next_project_stage
    end

    change_table :ticket_columns, bulk: true do |t|
      t.boolean :require_due_date, default: false, null: false
      t.boolean :require_scheduled_at, default: false, null: false
      t.boolean :require_appointment, default: false, null: false
      t.boolean :require_assignee, default: false, null: false
    end
  end
end
