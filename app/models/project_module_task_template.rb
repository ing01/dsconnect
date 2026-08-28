class ProjectModuleTaskTemplate < ApplicationRecord
  belongs_to :project_module
  belongs_to :project_task_template

  validates :project_task_template_id, uniqueness: { scope: :project_module_id }
end
