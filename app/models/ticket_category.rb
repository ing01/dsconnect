# A ticket's category ("Duvida", "Erro", "Homologacao"...), scoped to a Mesa.
# Same shape as TicketColumn: the Mesa owns the list, and two Mesas can have
# completely different ones.
class TicketCategory < ApplicationRecord
  # Mesmas cores que o WootLabel (components-next/label/Label.vue) aceita -
  # reaproveita o mesmo componente pra pintar o selo da Categoria no card do
  # Kanban, em vez de inventar uma paleta nova so' pra isto.
  COLORS = %w[slate amber teal ruby blue iris].freeze

  belongs_to :team
  # Estagio sugerido ao fechar um ticket desta Categoria (preenchimento
  # automatico no TicketCloseDialog, editavel antes de confirmar - pedido da
  # Ingrid, 2026-11-16). Tem que ser um Estagio da MESMA Mesa da Categoria,
  # senao a Mesa preenchida (a da propria Categoria) e o Estagio preenchido
  # nunca bateriam.
  belongs_to :default_ticket_column, class_name: 'TicketColumn', optional: true

  has_many :tickets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :team_id }
  validates :color, inclusion: { in: COLORS }, allow_blank: true
  validate :default_ticket_column_belongs_to_team

  before_validation :set_default_position, on: :create

  delegate :account, to: :team

  scope :ordered, -> { order(:position, :id) }
  # A lista da Area do Cliente. Ordenada por NOME, e nao por posicao: a posicao e
  # de dentro da Mesa, e aqui as Categorias vem de Mesas diferentes - ordenar por
  # ela embaralharia nomes sem criterio visivel para quem le.
  scope :client_visible, -> { where(client_visible: true).order(:name, :id) }

  def push_event_data
    { id: id, name: name, position: position, team_id: team_id,
      require_attachment: require_attachment, client_visible: client_visible,
      default_ticket_column_id: default_ticket_column_id, color: color }
  end

  private

  def default_ticket_column_belongs_to_team
    return if default_ticket_column.blank?

    errors.add(:default_ticket_column_id, :invalid) if default_ticket_column.team_id != team_id
  end

  def set_default_position
    return if position.present? && position != 0

    self.position = (team&.ticket_categories&.maximum(:position) || -1) + 1
  end
end
