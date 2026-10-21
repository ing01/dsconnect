require 'rails_helper'

# Gestao da chave da API de Integracao de Tickets - Configuracoes >
# Integracoes > API de Tickets. So' admin pode gerar/revogar; gerar de novo
# sempre substitui a chave anterior (uma por conta).
RSpec.describe 'Ticket API key management', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  def mostrar(user: administrator)
    get "/api/v1/accounts/#{account.id}/ticket_api_key", headers: user.create_new_auth_token, as: :json
  end

  def gerar(user: administrator)
    post "/api/v1/accounts/#{account.id}/ticket_api_key", headers: user.create_new_auth_token, as: :json
  end

  def revogar(user: administrator)
    delete "/api/v1/accounts/#{account.id}/ticket_api_key", headers: user.create_new_auth_token, as: :json
  end

  describe 'GET show' do
    it 'reports that no key exists yet' do
      mostrar
      expect(response.parsed_body['exists']).to be(false)
    end

    it 'never reveals the full token, only a masked version' do
      key = create(:ticket_api_key, account: account)
      mostrar
      expect(response.parsed_body['masked_token']).to end_with(key.token.last(4))
      expect(response.parsed_body['masked_token']).not_to eq(key.token)
    end

    it 'is forbidden for a non-admin agent' do
      mostrar(user: agent)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST create' do
    it 'generates a key and reveals the full token only this once' do
      gerar
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['token']).to be_present
      expect(account.reload.ticket_api_key).to be_present
    end

    it 'replaces the previous key instead of creating a second one' do
      gerar
      primeiro_token = response.parsed_body['token']

      gerar
      segundo_token = response.parsed_body['token']

      expect(segundo_token).not_to eq(primeiro_token)
      expect(TicketApiKey.where(account: account).count).to eq(1)
    end

    it 'is forbidden for a non-admin agent' do
      gerar(user: agent)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE destroy' do
    it 'revokes the key' do
      create(:ticket_api_key, account: account)
      revogar
      expect(response).to have_http_status(:success)
      expect(account.reload.ticket_api_key).to be_nil
    end
  end
end
