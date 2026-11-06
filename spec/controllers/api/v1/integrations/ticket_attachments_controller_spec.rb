require 'rails_helper'

RSpec.describe 'Ticket Attachments Integration API', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, ticket_column: column) }
  let(:file) { fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png') }

  describe 'POST /api/v1/integrations/tickets/:ticket_id/attachments' do
    it 'rejects a request without a key' do
      post "/api/v1/integrations/tickets/#{ticket.id}/attachments", params: { file: file }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'attaches the uploaded file to the ticket, with no human user' do
      post "/api/v1/integrations/tickets/#{ticket.id}/attachments", params: { file: file }, headers: headers

      expect(response).to have_http_status(:success)
      expect(ticket.ticket_attachments.count).to eq(1)
      attachment = ticket.ticket_attachments.first
      expect(attachment.user).to be_nil
      expect(response.parsed_body['filename']).to eq('avatar.png')
    end

    it '404s for a ticket from another account' do
      outro = create(:ticket)
      post "/api/v1/integrations/tickets/#{outro.id}/attachments", params: { file: file }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/integrations/tickets/:ticket_id/attachments' do
    it 'lists the ticket\'s attachments' do
      attachment = create(:ticket_attachment, ticket: ticket)

      get "/api/v1/integrations/tickets/#{ticket.id}/attachments", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([attachment.id])
    end
  end
end
