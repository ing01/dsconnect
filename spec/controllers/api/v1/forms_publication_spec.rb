require 'rails_helper'

# Formularios publicados na Central de Ajuda: o cliente logado preenche pela Area do Cliente, o
# formulario "aberto" tem um link sem login, e a resposta fica guardada SEM chamado.
RSpec.describe 'Formularios publicados', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:fields) do
    [
      { 'id' => 'f1', 'label' => 'Motivo', 'field_type' => 'short_text', 'required' => true },
      { 'id' => 'f2', 'label' => 'Tipo', 'field_type' => 'single_choice', 'options' => %w[Dúvida Erro] },
      { 'id' => 'f3', 'label' => 'Módulos', 'field_type' => 'multiple_choice', 'options' => %w[ERP PDV CRM] },
      { 'id' => 'f4', 'label' => 'Quando', 'field_type' => 'date' }
    ]
  end
  let!(:login_form) { account.forms.create!(name: 'Só logado', status: 'published', fields: fields, success_message: 'Recebemos!') }
  let!(:open_form) { account.forms.create!(name: 'Aberto', status: 'published', access_mode: 'open', fields: fields) }
  let!(:draft_form) { account.forms.create!(name: 'Rascunho', status: 'draft', access_mode: 'open', fields: fields) }

  let(:client) do
    contact = create(:contact, account: account, email: 'cliente@exemplo.com.br')
    contact.enable_client_access!(password: 'SenhaDoCliente@01')
    contact
  end

  def client_token
    client
    post '/api/v1/client/session', params: { email: 'cliente@exemplo.com.br', password: 'SenhaDoCliente@01' }, as: :json
    response.parsed_body['api_access_token']
  end

  describe 'o modelo' do
    it 'starts as login-only and generates the code of the link' do
      form = account.forms.create!(name: 'Novo')

      expect(form).to have_attributes(access_mode: 'login', status: 'draft')
      expect(form.public_token).to be_present
      expect(account.forms.create!(name: 'Outro').public_token).not_to eq(form.public_token)
    end

    it 'refuses an unknown access mode' do
      expect(account.forms.new(name: 'X', access_mode: 'qualquer')).not_to be_valid
    end

    it 'gives the right link for each mode' do
      expect(Forms::Links.fill_url(login_form)).to end_with("/app/client/forms/#{login_form.id}")
      expect(Forms::Links.fill_url(open_form)).to end_with("/app/forms/#{open_form.public_token}")
      expect(Forms::Links.public_url(login_form)).to be_nil
    end
  end

  describe 'Area do Cliente (cliente logado)' do
    let(:answers) { { f1: 'Preciso de ajuda', f2: 'Erro', f3: %w[ERP PDV], f4: '2026-11-18' } }

    def submit(form, params, token: client_token)
      post "/api/v1/client/forms/#{form.id}/form_responses", params: params, headers: { api_access_token: token }, as: :json
    end

    it 'requires the client session' do
      get "/api/v1/client/forms/#{login_form.id}", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'shows the form without the internal data' do
      get "/api/v1/client/forms/#{login_form.id}", headers: { api_access_token: client_token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to contain_exactly('id', 'name', 'description', 'success_message', 'fields')
    end

    it 'does not show a draft, nor a form of another account' do
      get "/api/v1/client/forms/#{draft_form.id}", headers: { api_access_token: client_token }, as: :json
      expect(response).to have_http_status(:not_found)

      other = create(:account).forms.create!(name: 'Outra', status: 'published')
      get "/api/v1/client/forms/#{other.id}", headers: { api_access_token: client_token }, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'stores the answers without a ticket, with the contact who answered' do
      submit(login_form, { answers: answers })

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['success_message']).to eq('Recebemos!')
      stored = login_form.form_responses.last
      expect(stored).to have_attributes(source: 'client', ticket_id: nil, contact_id: client.id)
      expect(stored.form_answers.find_by(field_id: 'f3').value).to eq(%w[ERP PDV])
    end

    it 'refuses what does not fit the form, saving nothing' do
      submit(login_form, { answers: { f1: 'x', f2: 'Inventada' } })
      expect(response).to have_http_status(:unprocessable_entity)

      submit(login_form, { answers: { f1: 'x', f4: 'ontem' } })
      expect(response).to have_http_status(:unprocessable_entity)

      submit(login_form, { answers: { f2: 'Erro' } })
      expect(response.parsed_body['message']).to include('Motivo')
      expect(login_form.form_responses.count).to eq(0)
    end

    it 'ignores questions that are not in the form' do
      submit(login_form, { answers: { f1: 'x', zzz: 'intruso' } })

      expect(login_form.form_responses.last.form_answers.pluck(:field_id)).to eq(['f1'])
    end
  end

  describe 'formulario aberto (sem login)' do
    let(:url) { "/public/api/v1/forms/#{open_form.public_token}" }

    it 'shows the open published form to anyone with the link' do
      get url, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('name' => 'Aberto', 'ask_respondent' => true)
      expect(response.parsed_body).not_to have_key('public_token')
    end

    it 'answers 404 for a login-only form, a draft and a wrong code' do
      [login_form.public_token, draft_form.public_token, 'codigo-errado'].each do |token|
        get "/public/api/v1/forms/#{token}", as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    it 'does not open by the database id' do
      get "/public/api/v1/forms/#{open_form.id}", as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'stores the answers, with the optional name and e-mail' do
      post "#{url}/responses", params: { answers: { f1: 'Oi' }, respondent_name: 'Maria', respondent_email: 'maria@exemplo.com' }, as: :json

      expect(response).to have_http_status(:created)
      expect(open_form.form_responses.last).to have_attributes(
        source: 'public', ticket_id: nil, contact_id: nil, respondent_name: 'Maria', respondent_email: 'maria@exemplo.com'
      )
    end

    it 'does not save a robot that fills the trap field, but pretends it worked' do
      post "#{url}/responses", params: { answers: { f1: 'Oi' }, website: 'http://spam' }, as: :json

      expect(response).to have_http_status(:created)
      expect(open_form.form_responses.count).to eq(0)
    end

    it 'validates the answers like any other source' do
      post "#{url}/responses", params: { answers: { f1: 'Oi', f2: 'Inventada' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(open_form.form_responses.count).to eq(0)
    end

    it 'limits the size of a text' do
      post "#{url}/responses", params: { answers: { f1: 'a' * 5_001 } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    describe 'arquivos' do
      let(:file_form) do
        account.forms.create!(name: 'Com arquivo', status: 'published', access_mode: 'open',
                              fields: [{ 'id' => 'doc', 'label' => 'Documento', 'field_type' => 'file_upload' }])
      end

      def upload(file)
        post "/public/api/v1/forms/#{file_form.public_token}/responses", params: { files: { doc: file } }
      end

      it 'accepts a common file type' do
        upload(Rack::Test::UploadedFile.new(StringIO.new('conteudo'), 'text/plain', original_filename: 'nota.txt'))

        expect(response).to have_http_status(:created)
        expect(file_form.form_responses.last.form_answers.first.file).to be_attached
      end

      it 'refuses an executable or a script' do
        upload(Rack::Test::UploadedFile.new(StringIO.new('MZ'), 'application/x-msdownload', original_filename: 'virus.exe'))

        expect(response).to have_http_status(:unprocessable_entity)
        expect(file_form.form_responses.count).to eq(0)
      end
    end
  end

  describe 'o painel (agente)' do
    let(:base) { "/api/v1/accounts/#{account.id}/forms" }

    it 'lets an agent fill a form without a ticket, saved as internal' do
      post "#{base}/#{login_form.id}/form_responses", params: { answers: { f1: 'Teste' } }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      expect(login_form.form_responses.last).to have_attributes(source: 'internal', ticket_id: nil, filled_by_id: agent.id)
    end

    it 'sets the access mode and the message, and returns the links of a published form' do
      patch "#{base}/#{login_form.id}", params: { form: { access_mode: 'open', success_message: 'Obrigado' } },
                                        headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('access_mode' => 'open', 'success_message' => 'Obrigado')
      expect(response.parsed_body['public_url']).to end_with("/app/forms/#{login_form.reload.public_token}")
      expect(response.parsed_body['client_url']).to end_with("/app/client/forms/#{login_form.id}")
    end

    it 'does not give a public link to a form that is only login' do
      get "#{base}/#{login_form.id}", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['public_url']).to be_nil
    end

    it 'lists who answered and from where' do
      client
      Forms::SubmitService.new(form: login_form, source: 'client', contact: client, answers: { f1: 'x' }).perform

      get "#{base}/#{login_form.id}/form_responses", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body.first).to include('source' => 'client', 'contact_name' => client.name, 'ticket_display_id' => nil)
    end
  end

  describe 'a Central de Ajuda (artigo publicado)' do
    let(:portal) { create(:portal, account_id: account.id) }
    let(:article) { create(:article, portal: portal, author: admin, content: 'Passo a passo') }

    it 'turns the form reference into the link to fill it, and drops the link of a draft form' do
      html = %(<a href="/dsref/form/#{open_form.id}">A</a> <a href="/dsref/form/#{login_form.id}">B</a> <a href="/dsref/form/#{draft_form.id}">C</a>)

      result = Articles::ReferenceResolver.new(html: html, portal: portal, mode: :public).call

      expect(result).to include(%(href="#{Forms::Links.fill_url(open_form)}"), %(href="#{Forms::Links.fill_url(login_form)}"))
      expect(result).not_to include('/dsref/')
      expect(result).to include('C')
    end

    it 'lists the published forms linked to the article' do
      open_form.update!(article: article)
      draft_form.update!(article: article)

      expect(article.forms.published.pluck(:id)).to eq([open_form.id])
    end
  end
end
