# Para qual Mesa um ticket aberto pelo PORTAL DO CLIENTE e' SUGERIDO de
# entrada, quando a Empresa tem um `client_level` (1 Baixa, 2 Media, 3 Alta)
# com Mesa configurada - por exemplo, Empresas de nivel Alto sempre sugerem
# uma Mesa de atendimento prioritario, nao importa qual Categoria o cliente
# escolheu.
#
# E so a sugestao: o chamado ainda entra na fila de Triagem como qualquer
# outro aberto pelo Portal, e um agente pode trocar a Mesa/Estagio na hora de
# aprovar. Esta regra so poupa esse trabalho quando a sugestao ja esta certa.
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
