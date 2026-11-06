# Lista as Complexidades da CONTA (TicketComplexity e' por conta, nao por
# Mesa - ver o model), para a IA/sistema externo saber quais ids sao validos
# em `ticket_complexity_id` no `PATCH /integrations/tickets/:id/route` ou no
# `POST /integrations/tickets`. So' as ativas: uma desligada nao e' uma
# opcao valida pra ninguem escolher, interno ou externo.
class Api::V1::Integrations::TicketComplexitiesController < Api::V1::Integrations::BaseController
  def index
    @ticket_complexities = current_account.ticket_complexities.active.ordered
  end
end
