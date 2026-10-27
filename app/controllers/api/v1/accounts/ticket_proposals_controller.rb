class Api::V1::Accounts::TicketProposalsController < Api::V1::Accounts::BaseController
  DEFAULT_LOCATION = 'Presidente Prudente'.freeze
  DEFAULT_PAYMENT_TERMS = '50% na aprovação da proposta e 50% na entrega da melhoria'.freeze

  before_action :fetch_ticket
  before_action :fetch_proposal, only: [:update, :destroy, :pdf]
  before_action :check_authorization
  # Depois de decidida, a proposta e' o registro do que o cliente aprovou ou
  # recusou: nao muda mais e nao some.
  before_action :reject_decided, only: [:update, :destroy]

  def index
    @ticket_proposals = @ticket.ticket_proposals.ordered.includes(:decided_by_contact)
  end

  # O que o formulario traz preenchido: os dados da Empresa do ticket e os
  # padroes comerciais. O agente ajusta o que precisar antes de salvar.
  def defaults
    company = @ticket.company
    render json: {
      summary: @ticket.title,
      items: [{ title: "#{@ticket.display_id} - #{@ticket.title}", description: '', amount: '' }],
      company_name: company&.name,
      company_cnpj: company&.cnpj,
      company_address: company_address(company),
      location: DEFAULT_LOCATION,
      payment_terms: DEFAULT_PAYMENT_TERMS,
      signer_name: Current.user.name,
      proposal_date: Time.zone.today
    }
  end

  def create
    @ticket_proposal = @ticket.ticket_proposals.create!(
      proposal_params.merge(account: Current.account, user: Current.user)
    )
    render 'show'
  end

  def update
    @ticket_proposal.update!(proposal_params)
    render 'show'
  end

  def destroy
    @ticket_proposal.destroy!
    head :ok
  end

  def pdf
    send_data Tickets::Proposals::PdfBuilder.new(proposal: @ticket_proposal).render,
              filename: "proposta-#{@ticket.display_id}-#{@ticket_proposal.id}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  end

  private

  def check_authorization(model = nil)
    super(model || @ticket_proposal || TicketProposal)
  end

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def fetch_proposal
    @ticket_proposal = @ticket.ticket_proposals.find(params[:id])
  end

  def reject_decided
    return unless @ticket_proposal.decided?

    render json: { error: I18n.t('tickets.proposals.already_decided'), code: 'proposal_decided' }, status: :unprocessable_entity
  end

  def proposal_params
    params.require(:ticket_proposal).permit(
      :company_name, :company_cnpj, :company_address, :summary, :proposal_date, :valid_until,
      :location, :payment_terms, :deadline_days, :signer_name, :visible_to_client,
      items: [:title, :description, :amount]
    )
  end

  def company_address(company)
    return if company.blank?

    street = [company.address_street, company.address_number].compact_blank.join(', ')
    city = [company.address_city, company.address_state].compact_blank.join(' - ')
    [street, company.address_neighborhood, city].compact_blank.join(' - ').presence
  end
end
