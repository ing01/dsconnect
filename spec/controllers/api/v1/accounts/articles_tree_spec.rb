require 'rails_helper'

# A arvore da Base de Conhecimento: pastas (Categorias), subartigos, reorganizacao,
# referencias entre artigos/formularios e o preenchimento de formulario a partir do artigo.
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe 'Base de Conhecimento - arvore', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:portal) { create(:portal, account_id: account.id, config: { allowed_locales: %w[en pt] }) }
  let!(:pops) { create(:category, name: 'Processos', portal: portal, locale: 'en', slug: 'processos', position: 1) }
  let!(:systems) { create(:category, name: 'Sistemas', portal: portal, locale: 'en', slug: 'sistemas', position: 2) }
  let!(:pt_folder) { create(:category, name: 'Pasta PT', portal: portal, locale: 'pt', slug: 'pasta-pt', position: 3) }
  let!(:pop1) { create(:article, portal: portal, category: pops, author: admin, title: 'POP 1', position: 10) }
  let!(:pop11) { create(:article, portal: portal, category: pops, author: admin, title: 'POP 1.1', parent_article: pop1, position: 10) }
  let!(:pop2) { create(:article, portal: portal, category: pops, author: admin, title: 'POP 2', position: 20) }
  let(:base) { "/api/v1/accounts/#{account.id}/portals/#{portal.slug}/articles" }

  def move(article, params, user: admin)
    patch "#{base}/#{article.id}/move", params: params, headers: user.create_new_auth_token, as: :json
  end

  describe 'Article model' do
    it 'keeps the child in the folder of the parent, even when created in another one' do
      child = create(:article, portal: portal, category: systems, author: admin, parent_article: pop1)

      expect(child.reload.category_id).to eq(pops.id)
    end

    it 'refuses to be its own parent, a loop, or a parent of another portal/language' do
      expect(pop1.tap { |a| a.parent_article = pop1 }).not_to be_valid
      expect(pop1.tap { |a| a.parent_article = pop11 }).not_to be_valid
      other_portal_article = create(:article, portal: create(:portal, account_id: account.id), author: admin)
      expect(build(:article, portal: portal, author: admin, parent_article: other_portal_article)).not_to be_valid
    end

    it 'lifts the children to the parent of the deleted article' do
      grandchild = create(:article, portal: portal, author: admin, parent_article: pop11)

      pop11.destroy!

      expect(grandchild.reload.parent_article_id).to eq(pop1.id)
    end

    it 'lists ancestors and descendants' do
      grandchild = create(:article, portal: portal, author: admin, parent_article: pop11)

      expect(grandchild.ancestor_articles).to eq([pop11, pop1])
      expect(pop1.descendant_articles).to contain_exactly(pop11, grandchild)
    end
  end

  describe 'GET /articles/tree' do
    it 'returns the folders and the articles of the language, with the parent of each one' do
      get "#{base}/tree", params: { locale: 'en' }, headers: agent.create_new_auth_token

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body['categories'].pluck('id')).to contain_exactly(pops.id, systems.id)
      expect(body['articles'].find { |a| a['id'] == pop11.id }).to include('parent_article_id' => pop1.id, 'category_id' => pops.id)
    end

    it 'requires authentication' do
      get "#{base}/tree"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /articles/:id/move' do
    it 'moves an article, with its sub-articles, to another folder' do
      move(pop1, { category_id: systems.id })

      expect(response).to have_http_status(:ok)
      expect([pop1, pop11].map { |a| a.reload.category_id }).to all(eq(systems.id))
    end

    it 'makes an article the child of another, in the folder of the new parent' do
      other = create(:article, portal: portal, category: systems, author: admin, title: 'Outro')

      move(pop2, { parent_article_id: other.id })

      expect(pop2.reload).to have_attributes(parent_article_id: other.id, category_id: systems.id)
    end

    it 'takes a child back to the root of a folder' do
      move(pop11, { parent_article_id: nil, category_id: pops.id })

      expect(pop11.reload.parent_article_id).to be_nil
    end

    it 'places the article at the chosen position among the siblings' do
      move(pop2, { category_id: pops.id, parent_article_id: nil, index: 0 })

      roots = portal.articles.where(category_id: pops.id, parent_article_id: nil).order(:position).pluck(:id)
      expect(roots).to eq([pop2.id, pop1.id])
    end

    it 'refuses to put an article under its own descendant' do
      move(pop1, { parent_article_id: pop11.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(pop1.reload.parent_article_id).to be_nil
    end

    it 'refuses a folder of another language' do
      move(pop2, { category_id: pt_folder.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(pop2.reload.category_id).to eq(pops.id)
    end

    it 'is not allowed for an agent without the knowledge base role' do
      move(pop2, { category_id: systems.id }, user: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(pop2.reload.category_id).to eq(pops.id)
    end
  end

  describe 'GET /articles/:id (show)' do
    let!(:form) { account.forms.create!(name: 'Abertura', status: 'published', article: pop1, fields: []) }

    it 'brings the ancestors, the linked published forms and the rendered content' do
      pop11.update!(content: "Veja o [POP 2](/dsref/article/#{pop2.id}) e o [form](/dsref/form/#{form.id}).")

      get "#{base}/#{pop11.id}", headers: agent.create_new_auth_token

      payload = response.parsed_body['payload']
      expect(payload['ancestors']).to eq([{ 'id' => pop1.id, 'title' => pop1.title }])
      expect(payload['parent_article_id']).to eq(pop1.id)
      expect(payload['rendered_content']).to include(%(data-ref-type="article"), %(data-ref-id="#{pop2.id}"), %(data-ref-type="form"))
    end

    it 'shows the forms of the article' do
      get "#{base}/#{pop1.id}", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload']['forms'].pluck('id')).to eq([form.id])
    end
  end

  describe Articles::ReferenceResolver do
    let(:html) { %(<p><a href="/dsref/article/#{pop2.id}">POP 2</a> <a href="/dsref/form/9">Form</a> <a href="/dsref/article/0">Sumiu</a></p>) }

    it 'marks a missing target as broken in the dashboard' do
      result = described_class.new(html: html, portal: portal, mode: :dashboard).call

      expect(result).to include('data-ref-broken="true"')
    end

    it 'links only the published articles in the public portal and turns the rest into text' do
      result = described_class.new(html: html, portal: portal, mode: :public).call

      expect(result).to include(%(href="/hc/#{portal.slug}/articles/#{pop2.slug}"))
      expect(result).not_to include('/dsref/')
      expect(result).to include('Form', 'Sumiu')
    end

    it 'does not link a draft article in the public portal' do
      pop2.update!(status: :draft)

      result = described_class.new(html: html, portal: portal, mode: :public).call

      expect(result).not_to include("/articles/#{pop2.slug}")
    end
  end

  describe 'POST /forms/:id/form_responses (preencher a partir do artigo)' do
    let!(:form) do
      account.forms.create!(name: 'Abertura', status: 'published', article: pop1,
                            fields: [{ 'id' => 'f1', 'label' => 'Motivo', 'field_type' => 'short_text', 'required' => true }])
    end
    let(:team) { create(:team, account: account) }
    let(:column) { create(:ticket_column, team: team) }
    let!(:ticket) { create(:ticket, account: account, team: team, ticket_column: column, ticket_category: create(:ticket_category, team: team)) }
    let(:url) { "/api/v1/accounts/#{account.id}/forms/#{form.id}/form_responses" }

    def fill(user: agent, **params)
      post url, params: params, headers: user.create_new_auth_token, as: :json
    end

    it 'lets any agent fill the form, linked to the ticket' do
      fill(ticket_display_id: ticket.display_id, answers: { f1: 'Cliente novo' })

      expect(response).to have_http_status(:created)
      response_record = form.form_responses.last
      expect(response_record).to have_attributes(ticket_id: ticket.id, filled_by_id: agent.id)
      expect(response_record.form_answers.pluck(:field_id, :value)).to eq([['f1', 'Cliente novo']])
    end

    it 'asks for the required questions' do
      fill(ticket_display_id: ticket.display_id, answers: {})

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('Motivo')
      expect(form.form_responses.count).to eq(0)
    end

    it 'does not accept an unknown ticket number' do
      fill(ticket_display_id: 99_999_999, answers: { f1: 'x' })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not fill a form that is still a draft' do
      form.update!(status: 'draft')

      fill(ticket_display_id: ticket.display_id, answers: { f1: 'x' })

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
