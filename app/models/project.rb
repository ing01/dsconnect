class Project < ApplicationRecord
  STAGES = %w[pendente onboarding requisito em_andamento acompanhamento pos finalizado].freeze

  belongs_to :account
  belongs_to :team
  belongs_to :company, optional: true
  belongs_to :contact, optional: true
  belongs_to :project_module, optional: true

  has_many :tickets, dependent: :nullify

  validates :name, presence: true
  validates :stage, inclusion: { in: STAGES }

  enum status: { active: 0, completed: 1, cancelled: 2 }

  before_validation :sync_status_with_stage

  scope :active_board, -> { where(status: :active).where.not(stage: 'finalizado') }
  scope :completed_board, -> { where(stage: 'finalizado').or(where(status: :completed)) }

  def advance_stage!(new_stage)
    return unless STAGES.include?(new_stage.to_s)

    update!(stage: new_stage.to_s)
  end

  private

  def sync_status_with_stage
    if stage == 'finalizado'
      self.status = :completed
    elsif completed? && stage != 'finalizado'
      self.status = :active
    end
  end
end
