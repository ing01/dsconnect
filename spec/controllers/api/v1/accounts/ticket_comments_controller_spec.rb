require 'rails_helper'

RSpec.describe 'Ticket Comments API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:ticket_column) { create(:ticket_column, team: create(:team, account: account)) }
  let(:ticket) { create(:ticket, ticket_column: ticket_column) }

  describe 'GET /api/v1/accounts/{account.id}/tickets/{ticket.id}/comments' do
    it 'lists comments oldest first' do
      create(:ticket_comment, account: account, ticket: ticket, user: agent, content: 'primeiro', created_at: 2.hours.ago)
      create(:ticket_comment, account: account, ticket: ticket, user: agent, content: 'segundo', created_at: 1.hour.ago)

      get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/comments",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('content')).to eq(%w[primeiro segundo])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/tickets/{ticket.id}/comments' do
    it 'creates a comment authored by the current user and logs an activity' do
      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/comments",
           params: { ticket_comment: { content: 'Cliente confirmou' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['content']).to eq('Cliente confirmou')
      expect(ticket.ticket_activities.where(activity_type: :comment_added)).to be_present
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/tickets/{ticket.id}/comments/:id' do
    it 'allows the author to delete their own comment' do
      comment = create(:ticket_comment, account: account, ticket: ticket, user: agent)

      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/comments/#{comment.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(TicketComment.exists?(comment.id)).to be(false)
    end

    it 'forbids another agent from deleting someone else\'s comment' do
      comment = create(:ticket_comment, account: account, ticket: ticket, user: agent)

      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/comments/#{comment.id}",
             headers: other_agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(TicketComment.exists?(comment.id)).to be(true)
    end
  end
end
