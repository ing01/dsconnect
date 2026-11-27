require 'rails_helper'

RSpec.describe 'Conversation customer briefing summary API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:company) { create(:company, name: 'Acme', domain: 'acme.com', account: account) }
  let(:contact) { create(:contact, account: account, company: company, name: 'Maria') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/customer_briefing/summary" }
  let(:answer) do
    { 'overview' => 'Erro de nota.', 'recent_topics' => ['NFS-e'], 'pending_items' => [], 'attention_points' => [] }
  end
  let(:ai) { instance_double(Captain::CustomerBriefingService, perform: { message: answer }) }

  before do
    account.enable_features!(:companies)
    allow(Captain::CustomerBriefingService).to receive(:new).and_return(ai)
  end

  def summarize(user: admin, params: {})
    post path, headers: user.create_new_auth_token, params: params, as: :json
    response.parsed_body
  end

  def history(text: 'Erro na nota', in_inbox: inbox)
    old = create(:conversation, account: account, inbox: in_inbox, contact: contact)
    create(:message, account: account, inbox: in_inbox, conversation: old, content: text)
    old
  end

  it 'requires authentication' do
    post path, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'refuses an agent without access to the conversation, without calling the AI' do
    history
    summarize(user: agent)

    expect(response).to have_http_status(:unauthorized)
    expect(Captain::CustomerBriefingService).not_to have_received(:new)
  end

  it 'answers that there is nothing to summarize, without calling the AI' do
    expect(summarize).to eq('summary' => nil, 'empty' => true)
    expect(Captain::CustomerBriefingService).not_to have_received(:new)
  end

  it 'generates and stores the summary' do
    history

    body = summarize

    expect(response).to have_http_status(:ok)
    expect(body).to include('summary' => answer, 'cached' => false)
    expect(body['generated_at']).to be_present
    expect(CustomerBriefingSummary.sole).to have_attributes(contact_id: contact.id, company_id: company.id)
  end

  it 'reuses the stored summary while nothing changes' do
    history
    summarize

    body = summarize

    expect(body).to include('summary' => answer, 'cached' => true)
    expect(ai).to have_received(:perform).once
  end

  it 'reuses it between people who see the same history' do
    create(:inbox_member, user: agent, inbox: inbox)
    history
    summarize

    expect(summarize(user: agent)['cached']).to be(true)
  end

  it 'generates again after a new message' do
    old = history
    summarize
    create(:message, account: account, inbox: inbox, conversation: old, content: 'Voltou o erro')

    expect(summarize['cached']).to be(false)
    expect(ai).to have_received(:perform).twice
  end

  it 'generates again after a new ticket' do
    history
    summarize
    create(:ticket, ticket_column: create(:ticket_column, team: create(:team, account: account)), company: company)

    expect(summarize['cached']).to be(false)
  end

  it 'generates again after a new note' do
    history
    summarize
    create(:note, contact: contact, content: 'Ligar à tarde')

    expect(summarize['cached']).to be(false)
  end

  it 'generates again when asked to' do
    history
    summarize

    expect(summarize(params: { force: true })['cached']).to be(false)
    expect(ai).to have_received(:perform).twice
    expect(CustomerBriefingSummary.count).to eq(1)
  end

  it 'does not give a person the text made from conversations they cannot see' do
    create(:inbox_member, user: agent, inbox: inbox)
    history
    history(text: 'assunto restrito', in_inbox: create(:inbox, account: account))
    summarize

    body = summarize(user: agent)

    expect(body['cached']).to be(false)
    expect(Captain::CustomerBriefingService).to have_received(:new)
      .with(hash_including(material: satisfy { |text| text.exclude?('assunto restrito') }))
  end

  it 'keeps a summary for each company of the contact' do
    second = create(:company, name: 'Beta', domain: 'beta.com', account: account)
    contact.company_contacts.create!(company: second)
    history
    summarize

    expect(summarize(params: { company_id: second.id })['cached']).to be(false)
    expect(CustomerBriefingSummary.pluck(:company_id)).to contain_exactly(company.id, second.id)
  end

  it 'hides technical errors and stores nothing' do
    history
    allow(ai).to receive(:perform).and_return(error: 'Net::ReadTimeout with #<TCPSocket>')

    body = summarize

    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to eq(I18n.t('captain.customer_briefing.failed'))
    expect(CustomerBriefingSummary.count).to eq(0)
  end

  it 'explains when the AI is off, without logging the agent out' do
    history
    allow(ai).to receive(:perform).and_return(error: 'A chave não está configurada.', error_code: 401)

    body = summarize

    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to eq('A chave não está configurada.')
  end

  it 'discards summaries of the contact that are too old' do
    stale = CustomerBriefingSummary.create!(account: account, contact: contact, fingerprint: 'antigo',
                                            content: {}, updated_at: 40.days.ago)
    history
    summarize

    expect(CustomerBriefingSummary.where(id: stale.id)).to be_empty
  end

  it 'deletes the summaries together with the contact' do
    history
    summarize
    other = create(:contact, account: account)
    kept = CustomerBriefingSummary.create!(account: account, contact: other, fingerprint: 'outro', content: {})

    contact.destroy!

    expect(CustomerBriefingSummary.all).to eq([kept])
  end
end
