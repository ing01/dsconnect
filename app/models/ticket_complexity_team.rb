# A disponibilidade de uma Complexidade numa Mesa - uma celula da matriz de
# Configuracoes > Tickets > Complexidade.
#
# Sem linha, a Mesa nao oferece aquele nivel. E por isso que a tabela existe em
# vez de uma coluna no ticket: a regra e da Mesa, nao do ticket, e mudar a Mesa
# nao pode reescrever o historico de quem ja escolheu.
class TicketComplexityTeam < ApplicationRecord
  belongs_to :ticket_complexity
  belongs_to :team

  validates :team_id, uniqueness: { scope: :ticket_complexity_id }
  validate :team_belongs_to_the_same_account

  private

  # A Complexidade e da conta; a Mesa tambem. Cruzar contas aqui vazaria o nome
  # de uma Mesa alheia para o formulario de outro cliente.
  def team_belongs_to_the_same_account
    return if team.blank? || ticket_complexity.blank?

    errors.add(:team, :invalid) if team.account_id != ticket_complexity.account_id
  end
end
