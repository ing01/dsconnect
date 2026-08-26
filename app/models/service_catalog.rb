# Level 1 of the service catalogue: the module or service being attended
# ("DS Comercial", "Instalação"). Deliberately independent of the Mesa - one
# Mesa attends several catalogues and the reverse is also true.
class ServiceCatalog < ApplicationRecord
  belongs_to :account

  has_many :service_catalog_areas, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :service_catalog
  has_many :service_catalog_items, through: :service_catalog_areas

  validates :name, presence: true, uniqueness: { scope: :account_id }

  before_validation :set_default_position, on: :create

  scope :ordered, -> { order(:position, :id) }
  scope :active, -> { where(active: true) }

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (account&.service_catalogs&.maximum(:position) || -1) + 1
  end
end
