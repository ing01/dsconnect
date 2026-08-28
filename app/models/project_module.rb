class ProjectModule < ApplicationRecord
  belongs_to :account

  has_many :project_module_task_templates, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :project_module
  has_many :project_task_templates, through: :project_module_task_templates
  has_many :projects, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
