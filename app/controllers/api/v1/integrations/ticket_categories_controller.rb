# Lista leve de Categorias por Mesa, para a IA externa saber quais ids sao
# validos para usar no `PATCH /integrations/tickets/:id/route`. Categoria e
# da Mesa (TicketCategory#team), por isso agrupada por Mesa, e nao uma lista
# plana.
class Api::V1::Integrations::TicketCategoriesController < Api::V1::Integrations::BaseController
  def index
    @teams = current_account.teams.includes(:ticket_categories).order(:name)
  end
end
