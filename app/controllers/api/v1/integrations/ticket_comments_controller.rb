# So' LEITURA: as notas internas da equipe (ex.: o que o analista escreveu ao
# analisar o ticket), pra um sistema externo (drift/analise automatica)
# conseguir ler o que a equipe ja registrou. Nao existe `create` aqui de
# proposito - TicketComment exige um `user` humano (nao e opcional no
# model), e esta API nao tem ator humano por tras da chamada (ver
# TicketApiKeyAuth). Quem precisa ESCREVER uma nota sem usuario usa
# `custom_attributes` (ver TicketsController#apply_custom_attributes) ou o
# campo `note` do `PATCH .../route`, que vira uma TicketActivity.
class Api::V1::Integrations::TicketCommentsController < Api::V1::Integrations::BaseController
  def index
    @ticket = current_account.tickets.find(params[:ticket_id])
    @ticket_comments = @ticket.ticket_comments.includes(:user).order(created_at: :asc)
  end
end
