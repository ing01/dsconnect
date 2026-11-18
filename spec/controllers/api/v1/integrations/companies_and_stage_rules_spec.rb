require 'rails_helper'

# A IA de triagem acha a Empresa (e o Nivel dela) pela API e move o ticket para Estagios
# que exigem responsavel, prazo ou agendamento.
RSpec.describe 'Ticket Integration API - Empresas e regras de Estagio', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:category) { create(:ticket_category, team: team) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /companies' do
    let!(:alfa) { create(:company, account: account, name: 'Alfa Mercado', codigo: 'A-100', classification_level: 4) }
    let!(:beta) { create(:company, account: account, name: 'Beta Farma', codigo: 'B-200') }

    def list(params = {})
      get '/api/v1/integrations/companies', params: params, headers: headers
      response.parsed_body
    end

    it 'lists the companies of the account with the level' do
      body = list

      expect(response).to have_http_status(:ok)
      expect(body['meta']['count']).to eq(2)
      expect(body['payload'].find { |c| c['id'] == alfa.id }).to include('name' => 'Alfa Mercado', 'classification_level' => 4)
      expect(body['payload'].find { |c| c['id'] == beta.id }['classification_level']).to be_nil
    end

    it 'finds by part of the name, ignoring case' do
      expect(list(query: 'farma')['payload'].pluck('id')).to eq([beta.id])
    end

    it 'finds by the exact code' do
      expect(list(codigo: 'a-100')['payload'].pluck('id')).to eq([alfa.id])
    end

    it 'finds by cnpj with or without punctuation' do
      alfa.update!(cnpj: '11222333000181')

      expect(list(cnpj: '11.222.333/0001-81')['payload'].pluck('id')).to eq([alfa.id])
    end

    it 'filters the classified and the not classified' do
      expect(list(classified: 'true')['payload'].pluck('id')).to eq([alfa.id])
      expect(list(classified: 'false')['payload'].pluck('id')).to eq([beta.id])
    end

    it 'does not list the companies of another account' do
      create(:company, account: create(:account), name: 'Alfa Outra Conta')

      expect(list(query: 'Alfa')['payload'].pluck('id')).to eq([alfa.id])
    end

    it 'shows one company and answers 404 for another account' do
      get "/api/v1/integrations/companies/#{alfa.id}", headers: headers
      expect(response.parsed_body).to include('id' => alfa.id, 'classification_level' => 4)

      get "/api/v1/integrations/companies/#{create(:company, account: create(:account)).id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'requires the api key' do
      get '/api/v1/integrations/companies'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /teams' do
    it 'tells what each stage requires' do
      create(:ticket_column, team: team, name: 'Exige', require_assignee: true, require_due_date: true)

      get '/api/v1/integrations/teams', headers: headers

      stage = response.parsed_body.find { |t| t['id'] == team.id }['ticket_columns'].find { |c| c['name'] == 'Exige' }
      expect(stage['requires']).to eq('assignee' => true, 'due_date' => true, 'scheduled_at' => false, 'appointment' => false)
    end
  end

  describe 'PATCH /tickets/:id into a stage with rules' do
    let(:strict) { create(:ticket_column, team: team, require_assignee: true, require_due_date: true, require_scheduled_at: true) }

    def move(params)
      patch "/api/v1/integrations/tickets/#{ticket.id}", params: params, headers: headers, as: :json
    end

    it 'is refused when the stage asks for what was not sent' do
      move(ticket_column_id: strict.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.ticket_column_id).to eq(column.id)
    end

    it 'moves when the assignee, due_date and scheduled_at come in the same call' do
      move(ticket_column_id: strict.id, assignee_id: agent.id,
           due_date: '2026-12-01T18:00:00-03:00', scheduled_at: '2026-11-30T09:00:00-03:00')

      expect(response).to have_http_status(:ok)
      expect(ticket.reload).to have_attributes(ticket_column_id: strict.id, assignee_id: agent.id)
      expect(ticket.due_date).to be_present
      expect(ticket.scheduled_at).to be_present
    end

    it 'refuses a date that is not a date, without changing the ticket' do
      move(due_date: 'amanha')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to eq(['due_date'])
    end

    it 'clears the due date when it comes blank' do
      ticket.update!(due_date: 1.day.from_now)

      move(due_date: '')

      expect(ticket.reload.due_date).to be_nil
    end

    it 'still sets only the assignee when the ticket does not move' do
      move(assignee_id: agent.id)

      expect(ticket.reload.assignee_id).to eq(agent.id)
    end
  end
end
