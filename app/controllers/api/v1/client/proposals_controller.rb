# As propostas comerciais do ticket, do lado do cliente: ler o PDF e decidir.
#
# So' enxerga a proposta que a equipe liberou (`visible_to_client`), de um ticket
# dentro de `visible_tickets` - trocar o id na URL cai em 404.
#
# A decisao e UNICA: `decide!` so grava enquanto a proposta esta pendente, e a
# segunda tentativa (outro clique, outra aba, outro contato da mesma empresa)
# recebe 409 sem alterar nada.
class Api::V1::Client::ProposalsController < Api::V1::Client::BaseController
  before_action :fetch_ticket
  before_action :fetch_proposal

  def pdf
    send_data Tickets::Proposals::PdfBuilder.new(proposal: @proposal).render,
              filename: "proposta-#{@ticket.display_id}-#{@proposal.id}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  end

  def approve
    decide('approved')
  end

  def refuse
    decide('refused')
  end

  private

  # A base busca por `params[:id]`; aqui o id da URL e' o da proposta.
  def fetch_ticket
    @ticket = visible_tickets.find(params[:ticket_id])
  end

  def fetch_proposal
    @proposal = @ticket.ticket_proposals.visible_to_client.find(params[:id])
  end

  def decide(decision)
    return render_error('proposal_expired', :unprocessable_entity) if @proposal.expired?
    return render_error('proposal_decided', :conflict) unless @proposal.decide!(decision, current_contact)

    # Em segundo plano - quem decidiu nao espera a bandeja do responsavel.
    Tickets::ProposalNotificationJob.perform_later(@proposal.id)

    render 'api/v1/client/proposals/show'
  end

  def render_error(code, status)
    render json: { error: I18n.t("client_area.proposal.#{code}"), code: code }, status: status
  end
end
