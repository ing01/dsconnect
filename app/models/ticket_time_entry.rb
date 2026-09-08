class TicketTimeEntry < ApplicationRecord
  CATEGORIES = %w[implantacao desenvolvimento dev_geral].freeze

  belongs_to :account
  belongs_to :ticket
  belongs_to :user

  validates :category, inclusion: { in: CATEGORIES }
  validates :hours, presence: true, numericality: { greater_than: 0 }
  validates :worked_on, presence: true

  before_validation :set_defaults, on: :create

  scope :ordered, -> { order(worked_on: :desc, id: :desc) }

  private

  def set_defaults
    self.worked_on ||= Time.zone.today
    self.user ||= Current.user
  end
end
