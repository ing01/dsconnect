require 'rails_helper'

# Nao havia nenhum spec cobrindo o fluxo "trocar senha pelo link do e-mail e
# logar com a senha nova em seguida" pro usuario interno (so existia pro
# Contato/Area do Cliente, em client_password_reset_spec.rb).
RSpec.describe 'Password reset then login', type: :request do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, email: 'reset-login@example.com', account: account, password: 'OldPass@123') }
  let(:browser_headers) { { 'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } }

  it 'allows login right after setting a new password via the e-mail reset token' do
    raw_token = user.send_reset_password_instructions

    put user_password_path, params: {
      reset_password_token: raw_token,
      password: 'NewPass@123',
      password_confirmation: 'NewPass@123'
    }, as: :json

    expect(response).to have_http_status(:success)

    post user_session_path, params: { email: user.email, password: 'NewPass@123' }, as: :json

    expect(response).to have_http_status(:success)
  end

  # O front (Edit.vue) so' valida tamanho minimo 6 - o backend (secure_password)
  # exige maiuscula+minuscula+numero+especial. Uma senha de 6+ caracteres que
  # passa no front mas nao no backend e' rejeitada aqui (a senha antiga
  # continua valendo), sem nenhum aviso de requisito na tela - so' esse texto
  # de erro generico. E' o cenario mais provavel pro relato de "a senha nova
  # nao funciona depois": a pessoa nao percebe que a troca nao foi aplicada.
  it 'rejects a password that passes the frontend minLength(6) but not the backend complexity rules' do
    raw_token = user.send_reset_password_instructions

    put user_password_path, params: {
      reset_password_token: raw_token,
      password: 'simples',
      password_confirmation: 'simples'
    }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.valid_password?('OldPass@123')).to be(true)
    expect(user.valid_password?('simples')).to be(false)
  end

  # Relato original: resetar a senha funciona (entra direto), mas ao sair da
  # conta e tentar logar de novo, batendo no limite de sessoes, o login
  # nunca pode ficar travado esperando a pessoa escolher o que encerrar - a
  # mais antiga e' descartada sozinha e o login segue.
  context 'when the account is already at the session limit' do
    before do
      25.times do |i|
        client_id = "client-#{i}"
        user.tokens[client_id] = { 'token' => BCrypt::Password.create('x'), 'expiry' => 30.days.from_now.to_i }
        user.user_sessions.create!(client_id: client_id, browser_name: 'Chrome', last_activity_at: i.minutes.ago)
      end
      user.save!
    end

    it 'logs in successfully, evicting the oldest session automatically' do
      oldest_client_id = user.user_sessions.order(:last_activity_at).first.client_id

      post user_session_path, params: { email: user.email, password: 'OldPass@123' },
                              headers: browser_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(user.reload.tokens).not_to have_key(oldest_client_id)
      expect(user.user_sessions.count).to eq(25)
    end

    it 'logging out (DELETE auth/sign_out) then logging in again does not get stuck at the limit' do
      post user_session_path, params: { email: user.email, password: 'OldPass@123' },
                              headers: browser_headers, as: :json
      expect(response).to have_http_status(:success)

      auth_headers = {
        'access-token' => response.headers['access-token'],
        'client' => response.headers['client'],
        'uid' => response.headers['uid']
      }

      delete destroy_user_session_path, headers: auth_headers.merge(browser_headers), as: :json
      expect(response).to have_http_status(:success)

      post user_session_path, params: { email: user.email, password: 'OldPass@123' },
                              headers: browser_headers, as: :json
      expect(response).to have_http_status(:success)
    end
  end
end
