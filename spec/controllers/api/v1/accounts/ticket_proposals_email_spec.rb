require 'rails_helper'

# Criar a proposta de melhoria com a caixinha "enviar por e-mail": o PDF vai ao solicitante e a
# proposta registra quando e para onde. A proposta fica salva mesmo quando o e-mail nao sai.
RSpec.describe 'Propostas de melhoria - envio por e-mail', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:category) { create(:ticket_category, team: team) }
  let(:company) { create(:company, account: account, name: 'Alfa Mercado') }
  let(:contact) { create(:contact, account: account, company: company, name: 'Renan', email: 'renan@alfa.com.br') }
  let(:ticket) do
    create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category,
                    company: company, contact: contact, title: 'Relatório de vendas')
  end
  let(:base) { "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/proposals" }

  let(:proposal_params) do
    {
      company_name: 'Alfa Mercado', summary: 'Novo relatório de vendas por vendedor', location: 'Presidente Prudente',
      payment_terms: '50% na aprovação e 50% na entrega', proposal_date: Time.zone.today.to_s,
      valid_until: 30.days.from_now.to_date.to_s, deadline_days: 20, signer_name: 'Maria',
      items: [{ title: 'Relatório', description: 'Por vendedor', amount: '1500' }]
    }
  end

  # O ApplicationMailer so' entrega com SMTP configurado (ou em desenvolvimento).
  before do
    allow_any_instance_of(TicketProposalMailer) # rubocop:disable RSpec/AnyInstance
      .to receive(:smtp_config_set_or_development?).and_return(true)
    ActionMailer::Base.deliveries.clear
  end

  def create_proposal(extra = {})
    post base, params: { ticket_proposal: proposal_params.merge(extra) }, headers: agent.create_new_auth_token, as: :json
  end

  def sent_mail
    ActionMailer::Base.deliveries.last
  end

  describe 'with the box ticked' do
    it 'e-mails the proposal to the requester with the PDF attached' do
      create_proposal(send_email: true)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['email']).to include('sent' => true, 'to' => 'renan@alfa.com.br')
      expect(sent_mail.to).to eq(['renan@alfa.com.br'])
      expect(sent_mail.subject).to include("##{ticket.display_id}", 'Novo relatório de vendas')
      expect(sent_mail.attachments.first.filename).to eq("proposta-#{ticket.display_id}-#{TicketProposal.last.id}.pdf")
      expect(sent_mail.attachments.first.content_type).to start_with('application/pdf')
    end

    it 'registers when and to whom it was sent, and shows it in the list' do
      create_proposal(send_email: true)

      proposal = TicketProposal.last
      expect(proposal).to have_attributes(emailed_to: 'renan@alfa.com.br')
      expect(proposal.emailed_at).to be_present

      get base, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.first).to include('emailed_to' => 'renan@alfa.com.br')
    end

    it 'points to the Client Portal only when the proposal is released there' do
      create_proposal(send_email: true)
      expect(sent_mail.body.encoded).not_to include('/app/client/tickets/')

      TicketProposal.last.update!(visible_to_client: true)
      Tickets::Proposals::EmailService.new(proposal: TicketProposal.last).perform
      expect(sent_mail.body.encoded).to include("/app/client/tickets/#{ticket.id}")
    end

    it 'keeps the proposal and warns when the requester has no e-mail' do
      contact.update!(email: nil)

      create_proposal(send_email: true)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['email']).to include('sent' => false, 'reason' => 'no_email')
      expect(TicketProposal.count).to eq(1)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it 'keeps the proposal and warns when the mail server did not deliver' do
      allow_any_instance_of(TicketProposalMailer) # rubocop:disable RSpec/AnyInstance
        .to receive(:smtp_config_set_or_development?).and_return(false)

      create_proposal(send_email: true)

      expect(response.parsed_body['email']).to include('sent' => false, 'reason' => 'not_delivered')
      expect(TicketProposal.last.emailed_at).to be_nil
    end
  end

  describe 'with the box not ticked' do
    it 'does not send anything and does not report an e-mail' do
      create_proposal(send_email: false)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).not_to have_key('email')
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(TicketProposal.last.emailed_at).to be_nil
    end

    it 'does not send when the option is not sent at all' do
      create_proposal

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe 'GET defaults' do
    it 'brings the e-mail of the requester, so the form knows whether it can send' do
      get "#{base}/defaults", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['requester_email']).to eq('renan@alfa.com.br')

      contact.update!(email: nil)
      get "#{base}/defaults", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['requester_email']).to be_nil
    end
  end
end
