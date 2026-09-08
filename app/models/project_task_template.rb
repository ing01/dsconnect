class ProjectTaskTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :default_assignee, class_name: 'User', optional: true
  belongs_to :checklist, optional: true

  has_many :project_module_task_templates, dependent: :destroy
  has_many :project_modules, through: :project_module_task_templates
  has_many :tickets, dependent: :nullify

  validates :name, presence: true
  validates :default_ticket_title, presence: true
  validates :due_days, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:name) }
end
