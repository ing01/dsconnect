require 'rails_helper'

# A senha padrao da Area do Cliente: todo solicitante (e-mail + Empresa) nasce com
# acesso e com a senha que a equipe entrega, e e obrigado a troca-la no primeiro
# acesso. Nada e enviado por e-mail.
RSpec.describe 'Senha padrao da Area do Cliente', type: :request do
  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }
  let(:padrao) { 'Padrao#Forte-2026!' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CLIENT_DEFAULT_PASSWORD').and_return(padrao)
    allow(ENV).to receive(:[]).with('CLIENT_DEFAULT_PASSWORD_EXPIRES_DAYS').and_return(nil)
  end

  def novo_solicitante(**attrs)
    create(:contact, account: account, email: 'pessoa@exemplo.com.br', company_id: empresa.id, **attrs)
  end

  # A web se identifica por este cabecalho (api/clientArea.js); o app do celular
  # nao manda - e entra normalmente com a senha padrao, sem troca.
  let(:web) { { 'X-Client-Platform' => 'web' } }

  def entrar(email: 'pessoa@exemplo.com.br', senha: padrao, headers: {})
    post '/api/v1/client/session', params: { email: email, password: senha }, headers: headers
  end

  def token
    response.parsed_body['api_access_token']
  end

  describe 'quem recebe' do
    it 'gives a new contact with e-mail and Empresa access with the default password' do
      contato = novo_solicitante

      expect(contato.reload).to have_attributes(client_access_enabled: true, password_change_required: true)
      expect(contato.valid_password?(padrao)).to be(true)
    end

    it 'does not give it to a contact without Empresa' do
      contato = create(:contact, account: account, email: 'solto@exemplo.com.br')

      expect(contato.reload.client_access_enabled).to be(false)
    end

    it 'does not give it to a contact without e-mail' do
      contato = create(:contact, account: account, company_id: empresa.id)

      expect(contato.reload.client_access_enabled).to be(false)
    end

    it 'never changes a contact that already has a password' do
      contato = create(:contact, account: account, email: 'ja@exemplo.com.br', company_id: empresa.id)
      contato.update!(password: 'SenhaPropria@01', password_change_required: false)

      contato.update!(email: 'ja2@exemplo.com.br')

      expect(contato.reload.valid_password?('SenhaPropria@01')).to be(true)
      expect(contato.password_change_required).to be(false)
    end

    it 'gives it when the link with the Empresa is created after the contact' do
      contato = create(:contact, account: account, email: 'depois@exemplo.com.br')
      expect(contato.reload.client_access_enabled).to be(false)

      CompanyContact.create!(contact: contato, company: empresa)

      expect(contato.reload).to have_attributes(client_access_enabled: true, password_change_required: true)
    end

    it 'does not touch a contact that already has client access' do
      contato = create(:contact, account: account, email: 'acesso@exemplo.com.br', company_id: empresa.id)
      contato.enable_client_access!(password: 'SenhaDoCliente@01')

      expect(contato.reload).to have_attributes(client_access_enabled: true, password_change_required: false)
      expect(contato.valid_password?('SenhaDoCliente@01')).to be(true)
    end

    it 'does nothing when no default password is configured' do
      allow(ENV).to receive(:[]).with('CLIENT_DEFAULT_PASSWORD').and_return(nil)

      expect(novo_solicitante.reload.client_access_enabled).to be(false)
    end
  end

  describe 'o primeiro acesso' do
    before { novo_solicitante }

    it 'tells the web screen the password must be changed' do
      entrar(headers: web)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['password_change_required']).to be(true)
    end

    it 'blocks everything but the password change on the web while on the default password' do
      entrar(headers: web)
      get '/api/v1/client/tickets', headers: web.merge('api_access_token' => token)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['code']).to eq('password_change_required')
    end

    # O app do celular entra normalmente com a senha padrao, sem troca de senha.
    it 'lets the mobile app in with the default password, with no password change' do
      entrar

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['password_change_required']).to be(false)

      get '/api/v1/client/tickets', headers: { 'api_access_token' => token }
      expect(response).not_to have_http_status(:forbidden)
      expect(response).not_to have_http_status(:unauthorized)
    end

    it 'lets the contact change the password and then use the area' do
      entrar(headers: web)
      put '/api/v1/client/password_change',
          params: { current_password: padrao, password: 'MinhaSenhaNova@9', password_confirmation: 'MinhaSenhaNova@9' },
          headers: web.merge('api_access_token' => token)

      expect(response).to have_http_status(:ok)

      get '/api/v1/client/tickets', headers: web.merge('api_access_token' => token)
      expect(response).not_to have_http_status(:forbidden)

      entrar(senha: 'MinhaSenhaNova@9', headers: web)
      expect(response.parsed_body['password_change_required']).to be(false)
    end

    it 'refuses a wrong current password' do
      entrar(headers: web)
      put '/api/v1/client/password_change',
          params: { current_password: 'errada', password: 'MinhaSenhaNova@9', password_confirmation: 'MinhaSenhaNova@9' },
          headers: web.merge('api_access_token' => token)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses the default password as the new one' do
      entrar(headers: web)
      put '/api/v1/client/password_change',
          params: { current_password: padrao, password: padrao, password_confirmation: padrao },
          headers: web.merge('api_access_token' => token)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a password shorter than 8 characters' do
      entrar(headers: web)
      put '/api/v1/client/password_change',
          params: { current_password: padrao, password: 'curta1', password_confirmation: 'curta1' },
          headers: web.merge('api_access_token' => token)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'validade da senha padrao' do
    it 'never expires by default' do
      contato = novo_solicitante
      contato.update_columns(default_password_set_at: 400.days.ago)

      entrar

      expect(response).to have_http_status(:ok)
    end

    it 'stops working after the configured days' do
      allow(ENV).to receive(:[]).with('CLIENT_DEFAULT_PASSWORD_EXPIRES_DAYS').and_return('7')
      contato = novo_solicitante
      contato.update_columns(default_password_set_at: 8.days.ago)

      entrar

      expect(response).to have_http_status(:unauthorized)
    end

    it 'still works inside the configured days' do
      allow(ENV).to receive(:[]).with('CLIENT_DEFAULT_PASSWORD_EXPIRES_DAYS').and_return('7')
      novo_solicitante.update_columns(default_password_set_at: 2.days.ago)

      entrar

      expect(response).to have_http_status(:ok)
    end
  end
end
