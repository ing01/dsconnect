require 'rails_helper'

# O parentesco do ticket pela API de Integracao: `parent_ticket_id` (o pai, ou nulo) e
# `child_tickets` (id, display_id, team_id, ticket_column_id e status; vazio quando nao ha),
# tanto no detalhe quanto na lista.
RSpec.describe 'Ticket Integration API - pai e filhos', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:team) { create(:team, account: account) }
  let(:dev_team) { create(:team, account: account, development_module_enabled: true) }
  let(:column) { create(:ticket_column, team: team) }
  let(:dev_column) { create(:ticket_column, team: dev_team) }
  let(:category) { create(:ticket_category, team: team) }

  let!(:parent) { create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category) }
  let!(:child_a) { create(:ticket, account: account, ticket_column: dev_column, team: dev_team, parent: parent) }
  let!(:child_b) { create(:ticket, account: account, ticket_column: column, team: team, parent: parent) }
  let!(:alone) { create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category) }

  def child_json(child)
    {
      'id' => child.id, 'display_id' => child.display_id, 'team_id' => child.team_id,
      'ticket_column_id' => child.ticket_column_id, 'status' => child.status
    }
  end

  describe 'GET /tickets/:id' do
    it 'lists the children of a parent, with the five fields, in id order' do
      get "/api/v1/integrations/tickets/#{parent.id}", headers: headers

      body = response.parsed_body
      expect(body['parent_ticket_id']).to be_nil
      expect(body['child_tickets']).to eq([child_json(child_a), child_json(child_b)])
    end

    it 'gives the parent id of a child, with an empty list of children' do
      get "/api/v1/integrations/tickets/#{child_a.id}", headers: headers

      body = response.parsed_body
      expect(body['parent_ticket_id']).to eq(parent.id)
      expect(body['child_tickets']).to eq([])
    end

    it 'gives null and an empty list for a ticket with no family' do
      get "/api/v1/integrations/tickets/#{alone.id}", headers: headers

      body = response.parsed_body
      expect(body['parent_ticket_id']).to be_nil
      expect(body['child_tickets']).to eq([])
    end

    it 'shows the current status of a finished child' do
      child_b.update_columns(status: Ticket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations

      get "/api/v1/integrations/tickets/#{parent.id}", headers: headers

      expect(response.parsed_body['child_tickets'].find { |c| c['id'] == child_b.id }['status']).to eq('closed')
    end
  end

  describe 'GET /tickets' do
    it 'brings parent_ticket_id and child_tickets on every ticket of the list' do
      get '/api/v1/integrations/tickets', headers: headers

      tickets = response.parsed_body['payload'].index_by { |t| t['id'] }
      expect(tickets[parent.id]).to include('parent_ticket_id' => nil, 'child_tickets' => [child_json(child_a), child_json(child_b)])
      expect(tickets[child_a.id]).to include('parent_ticket_id' => parent.id, 'child_tickets' => [])
      expect(tickets[alone.id]).to include('parent_ticket_id' => nil, 'child_tickets' => [])
    end

    it 'does not query the children once per ticket' do
      get '/api/v1/integrations/tickets', headers: headers # aquece caches/prepared statements

      queries = []
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/FROM "tickets" WHERE "tickets"."parent_id"/) }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get '/api/v1/integrations/tickets', headers: headers
      end

      expect(queries.size).to be <= 1
    end

    it 'never shows the family of a ticket from another account' do
      other_account = create(:account)
      other_parent = create(:ticket, account: other_account, ticket_column: create(:ticket_column, team: create(:team, account: other_account)),
                                     team: Team.where(account: other_account).first)

      get "/api/v1/integrations/tickets/#{other_parent.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
