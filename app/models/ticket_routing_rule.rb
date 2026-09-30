# Para onde um ticket aberto pelo PORTAL DO CLIENTE cai automaticamente,
# quando a Empresa tem um `client_level` (1 Baixa, 2 Media, 3 Alta) com Mesa
# configurada - por exemplo, Empresas de nivel Alto sempre caem numa Mesa de
# atendimento prioritario, nao importa qual Categoria o cliente escolheu.
#
# So vale para tickets do Portal: a triagem manual (fila de Triagem) continua
# existindo para os demais canais de abertura - e' esta regra que permite o
# Portal dispensar a triagem sem virar uma bagunca de tickets sem Mesa certa.
class TicketRoutingRule < ApplicationRecord
  CLIENT_LEVELS = { low: 1, medium: 2, high: 3 }.freeze

  belongs_to :account
  belongs_to :team

  validates :client_level, presence: true, inclusion: { in: CLIENT_LEVELS.values }
  validates :client_level, uniqueness: { scope: :account_id }
  validate :team_belongs_to_account

  private

  def team_belongs_to_account
    return if team.blank? || team.account_id == account_id

    errors.add(:team, :invalid)
  end
end
