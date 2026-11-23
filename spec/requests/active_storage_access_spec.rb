require 'rails_helper'

# O defeito real: o link de um anexo (o `file_url` da API, que redireciona para o
# link de disco do ActiveStorage) baixava o arquivo de QUALQUER pessoa, de aba
# anonima, sem login. O link "permanente" nem expira. Agora baixar pede a mesma
# credencial do resto do sistema - agente, cliente do Portal ou a chave da API de
# Integracao -, e so' o logo do Portal (pagina publica) continua aberto.
RSpec.describe 'Acesso aos anexos', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, email: 'cliente@exemplo.com.br') }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('conteudo secreto'), filename: 'anexo.txt',
                                           content_type: 'text/plain')
  end

  # `Accept` de imagem/fetch: o que `<img>` e o app mandam. O padrao do teste de
  # integracao inclui text/html, e ai a resposta seria o redirecionamento.
  let(:plain) { { 'Accept' => 'image/*' } }

  def blob_path(record = blob)
    # A rota de redirecionamento, de proposito: continua existindo (e guardada) mesmo com o modo
    # proxy como padrao, e e' ela que estes testes cobrem. O modo proxy tem os testes dele abaixo.
    Rails.application.routes.url_helpers.rails_storage_redirect_path(record, only_path: true)
  end

  # Um anexo "privado": preso a um registro que nao e' publico.
  before { contact.avatar.attach(blob) }

  def agent_headers
    agent.create_new_auth_token
  end

  def client_token
    contact.enable_client_access!(password: 'SenhaDoCliente@01')
    contact.client_access_token.token
  end

  describe 'cache do navegador (modo proxy)' do
    let(:image_blob) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new('PNGDATA'), filename: 'foto.png', content_type: 'image/png')
    end

    before { contact.avatar.attach(image_blob) }

    def proxy_path
      Rails.application.routes.url_helpers.rails_storage_proxy_path(image_blob, only_path: true)
    end

    it 'deixa o arquivo em cache SO no navegador de quem esta logado, nunca publico' do
      get proxy_path, headers: agent_headers.merge(plain)

      expect(response).to have_http_status(:ok)
      cache = response.headers['Cache-Control']
      expect(cache).to include('private', 'immutable')
      expect(cache).to match(/max-age=[0-9]{5,}/)
      expect(cache).not_to include('public')
    end

    it 'nao marca como cacheavel a recusa de quem nao tem login' do
      get proxy_path, headers: plain

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Cache-Control'].to_s).not_to include('immutable')
    end
  end

  describe 'sem login' do
    it 'recusa o link do anexo' do
      get blob_path, headers: plain

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('conteudo secreto')
    end

    it 'leva o navegador ao login em vez de mostrar uma tela em branco' do
      get blob_path, headers: { 'Accept' => 'text/html' }

      expect(response).to redirect_to('/app/login')
    end

    it 'recusa tambem o link de disco que o redirecionamento devolveria' do
      ActiveStorage::Current.url_options = { host: 'www.example.com', protocol: 'http' }

      get URI(blob.url).request_uri, headers: plain

      expect(response).to have_http_status(:unauthorized)
    end

    it 'recusa um token que nao existe' do
      get blob_path, headers: plain.merge('api_access_token' => 'token-inventado')

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'agente logado' do
    it 'baixa pelos cabecalhos do devise_token_auth' do
      get blob_path, headers: agent_headers.merge(plain)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('/rails/active_storage/disk/')
    end

    # E' o que faz `<img src>` e abrir o link numa aba nova funcionarem: o
    # navegador manda o cookie sozinho. O valor vai codificado, como o js-cookie faz.
    it 'baixa pelo cookie do painel' do
      credenciais = agent_headers.slice('access-token', 'client', 'uid')
      cookies['cw_d_session_info'] = CGI.escape(credenciais.to_json)

      get blob_path, headers: plain

      expect(response).to have_http_status(:redirect)
    end

    # O defeito real: o navegador (js-cookie) grava o `+` do e-mail LITERAL no cookie, e o Rack o lia
    # como espaco - quem tem `+` no e-mail (jean+x@...) nunca era achado e toda imagem dele era
    # recusada, mesmo logado. O valor aqui e' montado como o js-cookie faz.
    it 'baixa pelo cookie de quem tem + no e-mail de login' do
      jean = create(:user, account: account, role: :agent, email: 'jean+dsconnect@exemplo.com.br')
      credenciais = jean.create_new_auth_token.slice('access-token', 'client', 'uid')
      cookies['cw_d_session_info'] = CGI.escape(credenciais.to_json).gsub('%2B', '+')

      get blob_path, headers: plain

      expect(credenciais['uid']).to include('+')
      expect(response).to have_http_status(:redirect)
    end

    it 'recusa um token de agente errado' do
      credenciais = agent_headers.slice('access-token', 'client', 'uid').merge('access-token' => 'errado')
      cookies['cw_d_session_info'] = CGI.escape(credenciais.to_json)

      get blob_path, headers: plain

      expect(response).to have_http_status(:unauthorized)
    end

    it 'entrega o arquivo no link de disco' do
      ActiveStorage::Current.url_options = { host: 'www.example.com', protocol: 'http' }

      get URI(blob.url).request_uri, headers: agent_headers.merge(plain)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('conteudo secreto')
    end
  end

  describe 'cliente do Portal' do
    it 'baixa pelo cabecalho do app' do
      get blob_path, headers: plain.merge('api_access_token' => client_token)

      expect(response).to have_http_status(:redirect)
    end

    it 'baixa pelo cookie do Portal web' do
      cookies['cw_client_session'] = CGI.escape({ token: client_token }.to_json)

      get blob_path, headers: plain

      expect(response).to have_http_status(:redirect)
    end

    # A sessao cai na proxima requisicao quando a equipe desliga o acesso.
    it 'perde o acesso quando a equipe o desliga' do
      token = client_token
      contact.update!(client_access_enabled: false)

      get blob_path, headers: plain.merge('api_access_token' => token)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'integracao de tickets' do
    it 'baixa com a chave da API' do
      chave = create(:ticket_api_key, account: account)

      get blob_path, headers: plain.merge('X-Ticket-Api-Key' => chave.token)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'o que e publico' do
    it 'serve o logo do Portal sem login' do
      portal = create(:portal, account: account)
      logo = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('png'), filename: 'logo.png',
                                                    content_type: 'image/png')
      portal.logo.attach(logo)

      get blob_path(logo), headers: plain

      expect(response).to have_http_status(:redirect)
    end

    it 'nao deixa o arquivo sem dono virar publico' do
      orfao = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('x'), filename: 'x.txt',
                                                     content_type: 'text/plain')

      get blob_path(orfao), headers: plain

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'a valvula de emergencia' do
    it 'volta ao comportamento antigo com ACTIVE_STORAGE_REQUIRE_LOGIN=false' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_REQUIRE_LOGIN', 'true').and_return('false')

      get blob_path, headers: plain

      expect(response).to have_http_status(:redirect)
    end
  end
end
