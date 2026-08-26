# Level 3, and the only level a Ticket points at: the two above it are reached
# through the association rather than copied onto the ticket.
class ServiceCatalogItem < ApplicationRecord
  belongs_to :service_catalog_area

  # `restrict_with_error`: an item a ticket was classified with must not vanish.
  # Admins deactivate it instead, which keeps it out of the pickers while every
  # ticket that used it stays readable.
  has_many :tickets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :service_catalog_area_id }

  before_validation :set_default_position, on: :create

  delegate :service_catalog, to: :service_catalog_area
  delegate :account, :account_id, to: :service_catalog_area

  scope :ordered, -> { order(:position, :id) }
  scope :active, -> { where(active: true) }

  # "DS Comercial > Movimentações > Notas Fiscais de Mercadorias"
  def full_path
    [service_catalog.name, service_catalog_area.name, name]
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (service_catalog_area&.service_catalog_items&.maximum(:position) || -1) + 1
  end
end
