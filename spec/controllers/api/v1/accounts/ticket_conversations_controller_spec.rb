require 'rails_helper'

RSpec.describe 'Ticket Conversations API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:ticket) { create(:ticket, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  describe 'POST .../tickets/:ticket_id/ticket_conversations' do
    it 'links the conversation to the ticket' do
      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/ticket_conversations",
           params: { ticket_conversation: { conversation_id: conversation.id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.conversations).to include(conversation)
    end

    it 'rejects linking the same conversation twice' do
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/ticket_conversations",
           params: { ticket_conversation: { conversation_id: conversation.id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE .../tickets/:ticket_id/ticket_conversations/:id' do
    it 'unlinks the conversation using the conversation id' do
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/ticket_conversations/#{conversation.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.conversations).to be_empty
    end
  end
end
