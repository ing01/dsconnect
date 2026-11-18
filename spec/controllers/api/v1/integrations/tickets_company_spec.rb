require 'rails_helper'

# A API de Integracao aceita a Empresa do ticket e o Nivel dela (1 a 5, campo da
# Empresa) - na criacao e na atualizacao - e devolve o Nivel nas respostas.
RSpec.describe 'Ticket Integration API - Empresa e Nivel da empresa', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:category) { create(:ticket_category, team: team) }
  let(:company) { create(:company, account: account) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category) }

  def create_ticket(extra = {})
    post '/api/v1/integrations/tickets', headers: headers, as: :json,
                                         params: { ticket: { title: 'Erro', description: 'Detalhe', priority: 'medium',
                                                             ticket_category_id: category.id, ticket_column_id: column.id }.merge(extra) }
  end

  def update_ticket(params)
    patch "/api/v1/integrations/tickets/#{ticket.id}", params: params, headers: headers, as: :json
  end

  describe 'POST /tickets' do
    it 'creates the ticket for the company and sets the level of the company' do
      create_ticket(company_id: company.id, company_classification_level: 3)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['company']).to include('id' => company.id, 'classification_level' => 3)
      expect(company.reload.classification_level).to eq(3)
    end

    it 'accepts only the company, leaving the level alone' do
      company.update!(classification_level: 2)

      create_ticket(company_id: company.id)

      expect(response).to have_http_status(:created)
      expect(company.reload.classification_level).to eq(2)
    end

    it 'refuses a level outside 1 to 5 without creating the ticket' do
      expect { create_ticket(company_id: company.id, company_classification_level: 6) }.not_to change(Ticket, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to eq(['company_classification_level'])
    end

    it 'refuses a level without a company' do
      expect { create_ticket(company_classification_level: 3) }.not_to change(Ticket, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to eq(['company_id'])
    end

    it 'answers 404 for a company of another account' do
      other = create(:company, account: create(:account))

      expect { create_ticket(company_id: other.id) }.not_to change(Ticket, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /tickets/:id' do
    it 'changes the company of the ticket and its level' do
      update_ticket(company_id: company.id, company_classification_level: 5)

      expect(response).to have_http_status(:success)
      expect(ticket.reload.company).to eq(company)
      expect(company.reload.classification_level).to eq(5)
      expect(response.parsed_body['company']['classification_level']).to eq(5)
    end

    it 'sets the level of the company the ticket already has' do
      ticket.update!(company: company)

      update_ticket(company_classification_level: 4)

      expect(response).to have_http_status(:success)
      expect(company.reload.classification_level).to eq(4)
    end

    it 'clears the level when it is blank' do
      company.update!(classification_level: 4)
      ticket.update!(company: company)

      update_ticket(company_classification_level: '')

      expect(company.reload.classification_level).to be_nil
    end

    it 'refuses a level outside 1 to 5 and keeps everything as it was' do
      ticket.update!(company: company)
      company.update!(classification_level: 2)

      update_ticket(company_classification_level: 0, priority: 'urgent')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(company.reload.classification_level).to eq(2)
      expect(ticket.reload.priority).not_to eq('urgent')
    end

    it 'refuses a level for a ticket without a company' do
      update_ticket(company_classification_level: 3)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to eq(['company_id'])
    end

    it 'answers 404 for a company of another account' do
      update_ticket(company_id: create(:company, account: create(:account)).id)

      expect(response).to have_http_status(:not_found)
      expect(ticket.reload.company).to be_nil
    end
  end

  describe 'reading' do
    it 'shows the level in the list' do
      company.update!(classification_level: 3)
      ticket.update!(company: company)

      get '/api/v1/integrations/tickets', headers: headers, as: :json

      item = response.parsed_body['payload'].find { |entry| entry['id'] == ticket.id }
      expect(item['company_classification_level']).to eq(3)
    end
  end
end
