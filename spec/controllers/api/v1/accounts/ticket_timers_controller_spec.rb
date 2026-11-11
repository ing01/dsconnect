require 'rails_helper'

RSpec.describe 'Ticket timers API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, ticket_column: column) }

  def url(path = '', ticket_id: ticket.id)
    "/api/v1/accounts/#{account.id}/tickets/#{ticket_id}/timers#{path}"
  end

  def headers_for(user)
    user.create_new_auth_token
  end

  describe 'POST /timers (iniciar)' do
    it 'starts a running timer for the person' do
      expect do
        post url, params: { category: 'desenvolvimento', note: 'tela de pedidos' }, headers: headers_for(agent), as: :json
      end.to change(TicketTimer, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('status' => 'running', 'category' => 'desenvolvimento', 'note' => 'tela de pedidos')
      expect(TicketTimer.last).to have_attributes(user_id: agent.id, ticket_id: ticket.id, account_id: account.id)
    end

    it 'clicking start twice does not duplicate: it gives back the same timer' do
      post url, headers: headers_for(agent), as: :json

      expect { post url, headers: headers_for(agent), as: :json }.not_to change(TicketTimer, :count)
      expect(response).to have_http_status(:success)
    end

    it 'refuses a category that does not exist' do
      post url, params: { category: 'invalida' }, headers: headers_for(agent), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(TicketTimer.count).to eq(0)
    end

    it 'pauses the timer that was running in another ticket' do
      other = create(:ticket, ticket_column: column)
      post url(ticket_id: other.id), headers: headers_for(agent), as: :json

      post url, headers: headers_for(agent), as: :json

      expect(TicketTimer.find_by(ticket_id: other.id)).not_to be_running
      expect(TicketTimer.find_by(ticket_id: ticket.id)).to be_running
    end

    it 'requires authentication' do
      post url, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'pause, resume and finish' do
    let!(:timer) { TicketTimer.start!(ticket: ticket, user: agent, category: 'desenvolvimento') }

    it 'pauses and keeps the elapsed time' do
      travel_to(2.hours.from_now) do
        post url("/#{timer.id}/pause"), headers: headers_for(agent), as: :json
      end

      expect(response.parsed_body).to include('status' => 'paused')
      expect(response.parsed_body['elapsed_seconds']).to be_within(2).of(2.hours.to_i)
    end

    it 'resumes a paused timer' do
      timer.pause!

      post url("/#{timer.id}/resume"), headers: headers_for(agent), as: :json

      expect(response.parsed_body).to include('status' => 'running')
    end

    it 'finishes: creates the time entry and returns it' do
      timer.update!(accumulated_seconds: 5400, started_at: nil)

      expect do
        post url("/#{timer.id}/finish"), headers: headers_for(agent), as: :json
      end.to change(TicketTimeEntry, :count).by(1).and change(TicketTimer, :count).by(-1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('hours' => '1.5', 'category' => 'desenvolvimento', 'user_id' => agent.id)
    end
  end

  describe 'DELETE /timers/:id (descartar)' do
    it 'discards without logging any hours' do
      timer = TicketTimer.start!(ticket: ticket, user: agent)

      expect do
        delete url("/#{timer.id}"), headers: headers_for(agent), as: :json
      end.to change(TicketTimer, :count).by(-1)

      expect(response).to have_http_status(:success)
      expect(TicketTimeEntry.count).to eq(0)
    end
  end

  describe 'GET /timers' do
    it 'lists only the timers of the person' do
      mine = TicketTimer.start!(ticket: ticket, user: agent)
      TicketTimer.start!(ticket: ticket, user: colleague)

      get url, headers: headers_for(agent), as: :json

      expect(response.parsed_body.pluck('id')).to eq([mine.id])
    end
  end

  describe 'timers of other people' do
    let!(:theirs) { TicketTimer.start!(ticket: ticket, user: colleague) }

    %w[pause resume finish].each do |action|
      it "cannot #{action} the timer of a colleague" do
        post url("/#{theirs.id}/#{action}"), headers: headers_for(agent), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'cannot discard the timer of a colleague' do
      expect { delete url("/#{theirs.id}"), headers: headers_for(agent), as: :json }.not_to change(TicketTimer, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'ticket of another account' do
    it 'does not exist for the person' do
      foreign = create(:ticket)

      post url(ticket_id: foreign.id), headers: headers_for(agent), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
