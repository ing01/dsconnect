class TicketTimeEntry < ApplicationRecord
  CATEGORIES = %w[implantacao desenvolvimento dev_geral].freeze

  belongs_to :account
  belongs_to :ticket
  belongs_to :user

  validates :category, inclusion: { in: CATEGORIES }
  # Nulo e valido: Mesa sem niveis aponta como sempre apontou.
  validates :level, inclusion: { in: AssigneeLeveled::LEVELS }, allow_nil: true
  validates :hours, presence: true, numericality: { greater_than: 0 }
  validates :worked_on, presence: true

  before_validation :set_defaults, on: :create

  scope :ordered, -> { order(worked_on: :desc, id: :desc) }
  scope :for_level, ->(level) { where(level: level) }

  private

  def set_defaults
    self.worked_on ||= Time.zone.today
    self.user ||= Current.user
    self.level ||= inferred_level
  end

  # Em que nivel quem apontou estava neste ticket. Gravado no momento do
  # apontamento: se o responsavel mudar depois, o que ja foi lancado continua
  # pertencendo ao nivel em que foi feito.
  def inferred_level
    return unless ticket&.assignee_levels_enabled?

    ticket.level_of(user_id)
  end
end
