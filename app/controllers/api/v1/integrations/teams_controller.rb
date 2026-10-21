# Lista leve de Mesas + Estagios, para a IA externa saber quais ids sao
# validos para usar no `PATCH /integrations/tickets/:id/route`.
class Api::V1::Integrations::TeamsController < Api::V1::Integrations::BaseController
  def index
    @teams = current_account.teams.includes(:ticket_columns).order(:name)
  end
end
