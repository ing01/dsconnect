require 'rails_helper'

describe '/swagger', type: :request do
  describe 'GET /swagger' do
    it 'renders swagger index.html' do
      get '/swagger'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('redoc')
      expect(response.body).to include('/swagger.json')
    end

    it 'does not render files outside the swagger directory' do
      get '/swagger/%2Fetc%2Fpasswd'
      expect(response).to have_http_status(:not_found)
    end

    # Fora de development/test, a doc so deve abrir com usuario/senha - e o
    # time externo que consome a API de Integracao de Tickets e quem recebe
    # essas credenciais.
    context 'when outside development and test' do
      before do
        allow(Rails.env).to receive_messages(development?: false, test?: false)
        stub_const('ENV', ENV.to_hash.merge('SWAGGER_DOCS_USER' => 'docs', 'SWAGGER_DOCS_PASSWORD' => 'secret'))
      end

      it 'requires basic auth' do
        get '/swagger'
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders with the right credentials' do
        get '/swagger', headers: { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('docs', 'secret') }
        expect(response).to have_http_status(:success)
      end
    end
  end
end
