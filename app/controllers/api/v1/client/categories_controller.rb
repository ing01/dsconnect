# As Categorias que o cliente pode escolher ao abrir um chamado.
#
# Lista plana: o cliente descreve o PROBLEMA, e Mesa e Estagio sao decisao da
# triagem. Mostrar a estrutura de Mesas a ele seria pedir que adivinhasse o
# organograma do atendimento.
#
# Mas Categoria e um conceito POR MESA, com nome unico apenas dentro dela: as
# mesmas seis existem em cada Mesa. Achatar tudo repetia cada nome uma vez por
# Mesa no select. Por isso a lista sai do que foi MARCADO como visivel ao
# cliente, e nao de tudo que existe - vide TicketCategory#client_visible.
class Api::V1::Client::CategoriesController < Api::V1::Client::BaseController
  def index
    @categories = TicketCategory.client_visible
                                .joins(:team)
                                .where(teams: { account_id: Current.account.id, active: true })
  end
end
