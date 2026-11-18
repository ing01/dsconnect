require 'rails_helper'

# A Observacao livre do ticket pela API de Integracao: sai no GET (detalhe e lista) e
# pode ser inserida, alterada ou removida ao criar ou alterar o ticket.
RSpec.describe 'Ticket Integration API - Observacao', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:category) { create(:ticket_category, team: team) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category) }

  def update_ticket(params)
    patch "/api/v1/integrations/tickets/#{ticket.id}", params: params, headers: headers, as: :json
  end

  def create_ticket(extra = {})
    post '/api/v1/integrations/tickets', headers: headers, as: :json,
                                         params: { ticket: { title: 'Erro', description: 'Detalhe', priority: 'medium',
                                                             ticket_category_id: category.id,
                                                             ticket_column_id: column.id }.merge(extra) }
  end

  it 'creates the ticket with an observation' do
    create_ticket(observation: 'Cliente pediu retorno amanhã')

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['observation']).to eq('Cliente pediu retorno amanhã')
  end

  it 'creates the ticket without one' do
    create_ticket

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['observation']).to be_nil
  end

  it 'inserts, changes and removes the observation with PATCH' do
    update_ticket(observation: 'Primeira')
    expect(response.parsed_body['observation']).to eq('Primeira')

    update_ticket(observation: 'Segunda')
    expect(ticket.reload.observation).to eq('Segunda')

    update_ticket(observation: '')
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['observation']).to be_nil
    expect(ticket.reload.observation).to be_nil
  end

  it 'removes it with null too' do
    ticket.update!(observation: 'Algo')

    update_ticket(observation: nil)

    expect(ticket.reload.observation).to be_nil
  end

  it 'keeps the observation when the key is not sent' do
    ticket.update!(observation: 'Fica')

    update_ticket(priority: 'urgent')

    expect(ticket.reload.observation).to eq('Fica')
  end

  it 'shows the observation in the detail and in the list' do
    ticket.update!(observation: 'Aparece')

    get "/api/v1/integrations/tickets/#{ticket.id}", headers: headers, as: :json
    expect(response.parsed_body['observation']).to eq('Aparece')

    get '/api/v1/integrations/tickets', headers: headers, as: :json
    item = response.parsed_body['payload'].find { |entry| entry['id'] == ticket.id }
    expect(item['observation']).to eq('Aparece')
  end

  it 'records the change in the history of the ticket' do
    Current.user = nil
    update_ticket(observation: 'Nova')

    expect(ticket.ticket_activities.pluck(:activity_type)).to include('observation_changed')
  end

  it 'refuses an observation above the limit' do
    update_ticket(observation: 'a' * 100_001)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(ticket.reload.observation).to be_nil
  end
end
