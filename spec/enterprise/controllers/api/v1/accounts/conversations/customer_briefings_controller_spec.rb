require 'rails_helper'

RSpec.describe 'Conversation customer briefing API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:company) { create(:company, name: 'Acme', domain: 'acme.com', account: account) }
  let(:contact) { create(:contact, account: account, company: company, name: 'Maria') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:column) { create(:ticket_column, team: create(:team, account: account)) }

  before { account.enable_features!(:companies) }

  def briefing(user: admin, params: {})
    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/customer_briefing",
        headers: user.create_new_auth_token, params: params
    response.parsed_body
  end

  def conversation_with_message(of:, text:, in_inbox: inbox)
    item = create(:conversation, account: account, inbox: in_inbox, contact: of)
    create(:message, account: account, inbox: in_inbox, conversation: item, content: text, message_type: :incoming)
    item
  end

  it 'requires authentication' do
    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/customer_briefing"

    expect(response).to have_http_status(:unauthorized)
  end

  it 'refuses an agent without access to the conversation' do
    briefing(user: agent)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'shows the contact, the company and its tickets, open ones first' do
    open_ticket = create(:ticket, ticket_column: column, company: company, created_at: 2.days.ago)
    closed = create(:ticket, ticket_column: column, company: company)
    closed.update_columns(status: Ticket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations
    create(:note, contact: contact, content: 'Prefere ligação à tarde')

    body = briefing

    expect(body['contact']).to include('name' => 'Maria')
    expect(body['contact']['notes'].pluck('content')).to eq(['Prefere ligação à tarde'])
    expect(body['company']).to include('name' => 'Acme', 'tickets_count' => 2, 'open_tickets_count' => 1)
    expect(body['company'].keys).not_to include('billing_amount', 'implementation_fee')
    expect(body['tickets'].pluck('id')).to eq([open_ticket.id, closed.id])
  end

  it 'separates the previous conversations of the contact from those of colleagues' do
    own = conversation_with_message(of: contact, text: 'Erro na nota fiscal')
    colleague = create(:contact, account: account, company: company, name: 'José')
    other = conversation_with_message(of: colleague, text: 'Dúvida no estoque')
    create(:message, account: account, inbox: inbox, conversation: own, content: 'segredo', private: true,
                     message_type: :outgoing)

    body = briefing

    expect(body['contact_conversations'].pluck('display_id')).to eq([own.display_id])
    expect(body['contact_conversations'].first['last_message']).to eq('Erro na nota fiscal')
    expect(body['contact']['previous_conversations_count']).to eq(1)
    expect(body['company_conversations'].pluck('display_id')).to eq([other.display_id])
  end

  it 'hides conversations from inboxes the agent cannot see' do
    create(:inbox_member, user: agent, inbox: inbox)
    visible = conversation_with_message(of: contact, text: 'visível')
    conversation_with_message(of: contact, text: 'de outra caixa', in_inbox: create(:inbox, account: account))

    body = briefing(user: agent)

    expect(body['contact_conversations'].pluck('display_id')).to eq([visible.display_id])
  end

  it 'lets the screen choose among the companies of the contact' do
    second = create(:company, name: 'Beta', domain: 'beta.com', account: account)
    contact.company_contacts.create!(company: second)

    expect(briefing['company']['name']).to eq('Acme')
    expect(briefing['companies'].pluck('name')).to contain_exactly('Acme', 'Beta')
    expect(briefing(params: { company_id: second.id })['company']['name']).to eq('Beta')
  end

  it 'ignores a company that is not linked to the contact' do
    stranger = create(:company, name: 'Outra', domain: 'outra.com', account: account)

    expect(briefing(params: { company_id: stranger.id })['company']['name']).to eq('Acme')
  end

  it 'still works for a contact without a company' do
    contact.company_contacts.destroy_all
    contact.update!(company: nil)
    ticket = create(:ticket, ticket_column: column, contact: contact)

    body = briefing

    expect(body['company']).to be_nil
    expect(body['tickets'].pluck('id')).to eq([ticket.id])
    expect(body['company_conversations']).to eq([])
  end
end
