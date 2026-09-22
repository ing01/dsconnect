class AddSystemStartedOnToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :system_started_on, :date
  end
end
