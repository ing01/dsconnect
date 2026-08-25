require 'rails_helper'

RSpec.describe 'Ticket Attachments API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:ticket) { create(:ticket, account: account, ticket_column: create(:ticket_column, team: team), team: team) }
  let(:file) { fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png') }

  describe 'POST .../tickets/:ticket_id/attachments' do
    it 'is unauthorized without a token' do
      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/attachments", params: { file: file }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'attaches the file and records the uploader' do
      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/attachments",
           params: { file: file },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['filename']).to eq('avatar.png')
      expect(response.parsed_body['user']['id']).to eq(agent.id)
      expect(response.parsed_body['byte_size']).to be_positive
      expect(ticket.reload.ticket_attachments.count).to eq(1)
    end
  end

  describe 'GET .../attachments' do
    it 'lists the newest first' do
      create(:ticket_attachment, ticket: ticket, account: account, user: agent)
      create(:ticket_attachment, ticket: ticket, account: account, user: agent)

      get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/attachments",
          headers: agent.create_new_auth_token,
          as: :json

      ids = response.parsed_body.pluck('id')
      expect(ids).to eq(ids.sort.reverse)
    end
  end

  describe 'DELETE .../attachments/:id' do
    let!(:attachment) { create(:ticket_attachment, ticket: ticket, account: account, user: agent) }

    it 'lets the uploader remove it' do
      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/attachments/#{attachment.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(TicketAttachment.exists?(attachment.id)).to be(false)
    end

    it 'refuses another agent' do
      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/attachments/#{attachment.id}",
             headers: other_agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(TicketAttachment.exists?(attachment.id)).to be(true)
    end

    it 'lets an administrator remove anyone file' do
      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/attachments/#{attachment.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
    end
  end

  describe 'on the ticket payload' do
    it 'is exposed by the detail endpoint' do
      create(:ticket_attachment, ticket: ticket, account: account, user: agent)

      get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response.parsed_body['attachments'].first['filename']).to eq('avatar.png')
    end
  end
end
