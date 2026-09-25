# As Mesas as quais o cliente pode dirigir um chamado, com as Categorias de
# cada uma - e o que o formulario "Novo Ticket" precisa oferecer.
#
# So nome e categoria: nada de membros, niveis, prazos ou Estagios internos.
class Api::V1::Client::TeamsController < Api::V1::Client::BaseController
  def index
    @teams = Current.account.teams.active.includes(:ticket_categories).order(:name)
  end
end
