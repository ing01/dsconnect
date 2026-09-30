# A Complexidade do ticket ("Baixo", "Medio", "Alto"...).
#
# Lista da CONTA, como ServiceCatalog, e nao da Mesa como TicketCategory: o nome
# e o mesmo em toda a empresa, e o que varia e quais Mesas oferecem cada nivel -
# isso mora em `ticket_complexity_teams`.
#
# Nenhum nome esta fixo no codigo. Os tres iniciais sao semeados por
# `Tickets::DefaultComplexitiesBuilder`, e a partir dai a lista e so dado: criar
# um nivel novo, renomear ou desligar nao pede alteracao de codigo em lugar
# nenhum.
class TicketComplexity < ApplicationRecord
  belongs_to :account

  has_many :ticket_complexity_teams, dependent: :destroy
  has_many :teams, through: :ticket_complexity_teams
  # `nullify` porque apagar um nivel nao pode apagar o ticket que o usava - ele
  # apenas volta a ficar sem Complexidade.
  has_many :tickets, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }
  # O peso serve ao calculo de custo que vem depois; negativo nao significaria
  # nada ali, e recusar agora e mais barato que descobrir depois.
  validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :set_default_position, on: :create

  scope :ordered, -> { order(:position, :id) }
  scope :active, -> { where(active: true) }

  # Os niveis que uma Mesa oferece. Desligado na conta nao aparece em Mesa
  # nenhuma: `active` vale sobre a matriz.
  scope :available_for_team, lambda { |team_id|
    active.where(id: TicketComplexityTeam.where(team_id: team_id).select(:ticket_complexity_id))
  }

  # A matriz inteira numa consulta: quais Mesas cada nivel atende. A tela de
  # configuracao desenha exatamente isto, e uma consulta por linha seria uma por
  # nivel em cada abertura da tela.
  def self.team_ids_by_complexity(complexity_ids)
    return {} if complexity_ids.blank?

    TicketComplexityTeam.where(ticket_complexity_id: complexity_ids)
                        .pluck(:ticket_complexity_id, :team_id)
                        .group_by(&:first)
                        .transform_values { |pares| pares.map(&:last) }
  end

  # Substitui a lista de Mesas deste nivel. Em transacao porque a tela manda o
  # conjunto completo: aplicar metade deixaria a matriz num estado que ninguem
  # pediu.
  def replace_teams!(teams_ou_ids)
    pedidos = Array(teams_ou_ids).map { |item| item.respond_to?(:id) ? item.id : item.to_i }
    permitidos = account.team_ids & pedidos

    transaction do
      ticket_complexity_teams.where.not(team_id: permitidos).destroy_all
      permitidos.each { |team_id| ticket_complexity_teams.find_or_create_by!(team_id: team_id) }
    end
    reload
  end

  def available_for_team?(team_id)
    return false unless active?

    ticket_complexity_teams.exists?(team_id: team_id)
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (account&.ticket_complexities&.maximum(:position) || -1) + 1
  end
end
