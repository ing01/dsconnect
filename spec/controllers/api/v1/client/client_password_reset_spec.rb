require 'rails_helper'

# "Esqueci minha senha" para o cliente.
#
# O pedido entra pelo MESMO botao da tela de login - ela e compartilhada, e quem
# digita o e-mail nao tem como saber se e usuario interno ou contato. A troca em
# si tem endpoint proprio, porque o destino e outro: o contato volta para a Area
# do Cliente, nao para o painel.
RSpec.describe 'Redefinicao de senha da Area do Cliente', type: :request do
  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }

  let(:cliente) do
    create(:contact, account: account, email: 'cliente@exemplo.com.br',
                     company_id: empresa.id).tap do |contato|
      contato.enable_client_access!(password: 'SenhaDoCliente@01')
    end
  end

  def pedir_link(email)
    post '/auth/password', params: { email: email }
  end

  # O token que vai no e-mail e o cru; o banco guarda so o digerido.
  def token_do_email
    perform_enqueued_jobs { pedir_link(cliente.email) }
    ActionMailer::Base.deliveries.last.body.encoded[%r{password/edit\?token=([^"&\s]+)}, 1]
      .then { |bruto| CGI.unescape(bruto.to_s) }
  end

  before do
    # Materializa Empresa e contato AQUI, e nao dentro de `perform_enqueued_jobs`:
    # criar Empresa enfileira o job de favicon, que dentro daquele bloco rodaria
    # de verdade e tentaria sair para a rede.
    cliente
    ActionMailer::Base.deliveries.clear
  end

  describe 'o pedido do link' do
    it 'sends the e-mail to a contact with client access' do
      cliente
      perform_enqueued_jobs { pedir_link(cliente.email) }

      expect(ActionMailer::Base.deliveries.last.to).to eq([cliente.email])
    end

    # O link precisa apontar para a tela do CLIENTE. O caminho do painel pediria
    # sessao de usuario interno, que ele nao tem.
    it 'points at the client screen, with the token' do
      cliente
      perform_enqueued_jobs { pedir_link(cliente.email) }

      expect(ActionMailer::Base.deliveries.last.body.encoded)
        .to match(%r{/app/client/password/edit\?token=})
    end

    # Oferecer link de senha a quem nao pode entrar seria mostrar uma porta que
    # nao abre.
    it 'says nothing to a contact without client access' do
      sem_acesso = create(:contact, account: account, email: 'sem@exemplo.com.br')

      perform_enqueued_jobs { pedir_link(sem_acesso.email) }

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    # A resposta nao pode denunciar quem existe: a tela viraria um verificador
    # de cadastro.
    it 'answers the same for an e-mail nobody has' do
      perform_enqueued_jobs { pedir_link('ninguem@exemplo.com.br') }

      expect(response).to have_http_status(:success)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    # O usuario interno continua tendo precedencia - o fluxo dele nao muda.
    it 'still serves the internal user first' do
      usuario = create(:user, account: account, email: 'agente@exemplo.com.br')

      perform_enqueued_jobs { pedir_link(usuario.email) }

      expect(usuario.reload.reset_password_token).to be_present
    end
  end

  describe 'a troca da senha' do
    it 'accepts the token from the e-mail' do
      token = token_do_email

      put '/api/v1/client/password',
          params: { token: token, password: 'NovaSenha@01', password_confirmation: 'NovaSenha@01' }

      expect(response).to have_http_status(:success)
      expect(cliente.reload.valid_password?('NovaSenha@01')).to be(true)
    end

    it 'refuses a token that was never issued' do
      cliente

      put '/api/v1/client/password',
          params: { token: 'inventado', password: 'NovaSenha@01', password_confirmation: 'NovaSenha@01' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cliente.reload.valid_password?('SenhaDoCliente@01')).to be(true)
    end

    it 'refuses a token past its validity' do
      token = token_do_email

      travel_to(Devise.reset_password_within.from_now + 1.minute) do
        put '/api/v1/client/password',
            params: { token: token, password: 'NovaSenha@01', password_confirmation: 'NovaSenha@01' }
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cliente.reload.valid_password?('SenhaDoCliente@01')).to be(true)
    end

    it 'refuses when the confirmation does not match' do
      token = token_do_email

      put '/api/v1/client/password',
          params: { token: token, password: 'NovaSenha@01', password_confirmation: 'Outra@01' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Um link so serve uma vez: o Devise limpa o token ao gravar a senha.
    it 'burns the token after it is used' do
      token = token_do_email
      put '/api/v1/client/password',
          params: { token: token, password: 'NovaSenha@01', password_confirmation: 'NovaSenha@01' }

      put '/api/v1/client/password',
          params: { token: token, password: 'Terceira@01', password_confirmation: 'Terceira@01' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cliente.reload.valid_password?('NovaSenha@01')).to be(true)
    end

    # Quem redefine ou esqueceu a senha ou desconfia que alguem a tem: nos dois
    # casos a sessao aberta em outro lugar deve cair.
    it 'drops the session that was already open' do
      token = token_do_email
      cliente.client_access_token

      put '/api/v1/client/password',
          params: { token: token, password: 'NovaSenha@01', password_confirmation: 'NovaSenha@01' }

      expect(cliente.reload.access_token).to be_nil
    end

    # O acesso pode ter sido desligado depois de o e-mail sair.
    it 'refuses when the access was revoked meanwhile' do
      token = token_do_email
      cliente.disable_client_access!

      put '/api/v1/client/password',
          params: { token: token, password: 'NovaSenha@01', password_confirmation: 'NovaSenha@01' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
