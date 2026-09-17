# As duas acoes de impedimento do ticket.
#
# Extraido do TicketsController pelo mesmo motivo que o TicketListing e o
# TicketExporting: a classe estava no limite de tamanho. A regra em si mora no
# TicketBlocking, do lado do model - aqui fica so a borda HTTP.
module TicketImpedimentActions
  extend ActiveSupport::Concern

  # Impedimento: o ticket para de andar mas continua ABERTO, na mesma Mesa e no
  # mesmo estagio. O motivo e obrigatorio e vira um comentario interno.
  def block
    @ticket.block!(Current.user, reason: params[:reason])
    render 'show'
  rescue ArgumentError => e
    # Motivo em branco e erro do pedido, nao falha do servidor: o cliente precisa
    # conseguir mostrar a mensagem no formulario.
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def unblock
    @ticket.unblock!(Current.user)
    render 'show'
  end
end
