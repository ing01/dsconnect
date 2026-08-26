# Level 2: a subdivision of a catalogue ("Movimentações", "Cadastros").
class ServiceCatalogArea < ApplicationRecord
  belongs_to :service_catalog

  has_many :service_catalog_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :service_catalog_area

  validates :name, presence: true, uniqueness: { scope: :service_catalog_id }

  before_validation :set_default_position, on: :create

  delegate :account, :account_id, to: :service_catalog

  scope :ordered, -> { order(:position, :id) }
  scope :active, -> { where(active: true) }

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (service_catalog&.service_catalog_areas&.maximum(:position) || -1) + 1
  end
end
