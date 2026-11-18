require 'rails_helper'

# A "Estimativa original (horas)" pela API de Integracao: sai no GET (detalhe e lista) e
# pode ser inserida, alterada ou removida ao criar ou alterar o ticket.
RSpec.describe 'Ticket Integration API - Estimativa original (horas)', type: :request do
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

  it 'creates the ticket with an estimate' do
    create_ticket(estimativa_original_horas: 6)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['estimativa_original_horas']).to eq(6)
  end

  it 'comes null when there is none' do
    create_ticket

    expect(response.parsed_body['estimativa_original_horas']).to be_nil
  end

  it 'inserts, changes and removes it with PATCH' do
    update_ticket(estimativa_original_horas: 2.5)
    expect(response.parsed_body['estimativa_original_horas']).to eq(2.5)

    update_ticket(estimativa_original_horas: 8)
    expect(response.parsed_body['estimativa_original_horas']).to eq(8)

    update_ticket(estimativa_original_horas: nil)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['estimativa_original_horas']).to be_nil
  end

  it 'accepts a comma as the decimal separator' do
    update_ticket(estimativa_original_horas: '2,5')

    expect(ticket.reload.custom_attributes['estimativa_original_horas']).to eq(2.5)
  end

  it 'accepts it inside custom_attributes too, as a number' do
    update_ticket(custom_attributes: { estimativa_original_horas: '4' })

    expect(ticket.reload.custom_attributes['estimativa_original_horas']).to eq(4.0)
  end

  it 'keeps it when the key is not sent, and keeps the other custom attributes' do
    ticket.update!(custom_attributes: { 'estimativa_original_horas' => 3, 'outro' => 'x' })

    update_ticket(observation: 'texto')

    expect(ticket.reload.custom_attributes).to include('estimativa_original_horas' => 3, 'outro' => 'x')
  end

  it 'refuses a negative or non numeric value without changing the ticket' do
    update_ticket(estimativa_original_horas: -1)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['attributes']).to eq(['estimativa_original_horas'])

    update_ticket(estimativa_original_horas: 'muito')
    expect(response).to have_http_status(:unprocessable_entity)
    expect(ticket.reload.custom_attributes['estimativa_original_horas']).to be_nil
  end

  it 'refuses an invalid value on create' do
    create_ticket(estimativa_original_horas: 'abc')

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'shows it in the list' do
    ticket.update!(custom_attributes: { 'estimativa_original_horas' => 5 })

    get '/api/v1/integrations/tickets', headers: headers

    expect(response.parsed_body['payload'].first['estimativa_original_horas']).to eq(5)
  end
end
