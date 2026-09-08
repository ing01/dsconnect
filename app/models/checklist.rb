class Checklist < ApplicationRecord
  belongs_to :account
  has_many :project_task_templates, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
