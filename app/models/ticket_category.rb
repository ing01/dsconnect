# A ticket's category ("Duvida", "Erro", "Homologacao"...), scoped to a Mesa.
# Same shape as TicketColumn: the Mesa owns the list, and two Mesas can have
# completely different ones.
class TicketCategory < ApplicationRecord
  belongs_to :team

  has_many :tickets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :team_id }

  before_validation :set_default_position, on: :create

  delegate :account, to: :team

  scope :ordered, -> { order(:position, :id) }
  # A lista da Area do Cliente. Ordenada por NOME, e nao por posicao: a posicao e
  # de dentro da Mesa, e aqui as Categorias vem de Mesas diferentes - ordenar por
  # ela embaralharia nomes sem criterio visivel para quem le.
  scope :client_visible, -> { where(client_visible: true).order(:name, :id) }

  def push_event_data
    { id: id, name: name, position: position, team_id: team_id,
      require_attachment: require_attachment, client_visible: client_visible }
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (team&.ticket_categories&.maximum(:position) || -1) + 1
  end
end
