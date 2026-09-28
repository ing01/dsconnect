require 'rails_helper'

RSpec.describe 'Suggestions API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:column) { create(:suggestion_column, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/suggestions' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/suggestions"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists suggestions for a plain agent (board is open to everyone)' do
      create(:suggestion, suggestion_column: column, account: account, user: agent)

      get "/api/v1/accounts/#{account.id}/suggestions", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.size).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/suggestions' do
    it 'lets a plain agent submit a suggestion' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria', description: 'Detalhes' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['title']).to eq('Melhoria')
      expect(Suggestion.last.user).to eq(agent)
    end

    it 'creates the account default columns and lands the suggestion in the first one' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(account.suggestion_columns.count).to eq(5)
      expect(Suggestion.last.suggestion_column).to eq(account.suggestion_columns.order(:position).first)
    end

    it 'ignores assignee_id sent by a plain agent' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria', assignee_id: administrator.id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(Suggestion.last.assignee_id).to be_nil
    end

    it 'lets an administrator set the assignee on creation' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria', assignee_id: administrator.id } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(Suggestion.last.assignee).to eq(administrator)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/suggestions/:id' do
    it 'forbids a plain agent from setting the assignee' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: administrator.id } },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an administrator set and clear the assignee' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: administrator.id } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(suggestion.reload.assignee).to eq(administrator)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: '' } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(suggestion.reload.assignee_id).to be_nil
    end

    it 'rejects a plain agent as assignee' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: agent.id } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(suggestion.reload.assignee_id).to be_nil
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/suggestions/:id/move' do
    it 'forbids a plain agent from moving a suggestion' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)
      other_column = create(:suggestion_column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}/move",
            params: { suggestion_column_id: other_column.id, position: 0 },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an administrator move a suggestion between columns' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)
      other_column = create(:suggestion_column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}/move",
            params: { suggestion_column_id: other_column.id, position: 0 },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(suggestion.reload.suggestion_column).to eq(other_column)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/suggestions/:id' do
    it 'forbids a plain agent from deleting a suggestion' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      delete "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Suggestion.exists?(suggestion.id)).to be(true)
    end

    it 'lets an administrator delete a suggestion' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      delete "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(Suggestion.exists?(suggestion.id)).to be(false)
    end
  end

  # Prioridade, Categoria e tempo gasto. As duas primeiras sao listas
  # configuraveis da conta; o tempo gasto e um numero solto. Sao decisoes de
  # quem administra o quadro, e nao campos abertos a quem so esta enviando uma
  # sugestao.
  describe 'os campos de triagem' do
    let(:prioridade) { create(:suggestion_priority, account: account) }
    let(:categoria) { create(:suggestion_category, account: account) }

    def enviar(params, user: administrator)
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: params }, headers: user.create_new_auth_token, as: :json
    end

    def alterar(suggestion, params, user: administrator)
      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: params }, headers: user.create_new_auth_token, as: :json
    end

    it 'records all three when an administrator sends them' do
      enviar({ title: 'Melhoria', priority_id: prioridade.id, category_id: categoria.id,
               time_spent_hours: '2.5' })

      expect(response).to have_http_status(:success)
      suggestion = Suggestion.last
      expect(suggestion.priority).to eq(prioridade)
      expect(suggestion.category).to eq(categoria)
      expect(suggestion.time_spent_hours).to eq(2.5)
    end

    # A tela le os nomes direto do payload - sem eles o card mostraria um id.
    it 'answers with the names, not only the ids' do
      enviar({ title: 'Melhoria', priority_id: prioridade.id, category_id: categoria.id })

      expect(response.parsed_body['priority_name']).to eq(prioridade.name)
      expect(response.parsed_body['category_name']).to eq(categoria.name)
    end

    # Quem so envia uma sugestao nao decide a prioridade dela: o campo e'
    # ignorado em silencio, e a sugestao entra igual.
    it 'ignores them when a plain agent sends them' do
      enviar({ title: 'Melhoria', priority_id: prioridade.id, time_spent_hours: '8' }, user: agent)

      expect(response).to have_http_status(:success)
      suggestion = Suggestion.last
      expect(suggestion.title).to eq('Melhoria')
      expect(suggestion.priority_id).to be_nil
      expect(suggestion.time_spent_hours).to be_nil
    end

    it 'lets an administrator change and clear each one' do
      suggestion = create(:suggestion, suggestion_column: column, account: account,
                                       priority: prioridade, category: categoria, time_spent_hours: 4)

      alterar(suggestion, { priority_id: '', category_id: '', time_spent_hours: '' })

      expect(response).to have_http_status(:success)
      suggestion.reload
      expect(suggestion.priority_id).to be_nil
      expect(suggestion.category_id).to be_nil
      expect(suggestion.time_spent_hours).to be_nil
    end

    it 'forbids a plain agent from changing them' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      alterar(suggestion, { priority_id: prioridade.id }, user: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(suggestion.reload.priority_id).to be_nil
    end

    # A lista e' da conta. Apontar para a prioridade de outra conta revelaria
    # que ela existe, e traria o nome dela para dentro deste quadro.
    it 'refuses a priority from another account' do
      alheia = create(:suggestion_priority, account: create(:account))
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      alterar(suggestion, { priority_id: alheia.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(suggestion.reload.priority_id).to be_nil
    end

    it 'refuses a category from another account' do
      alheia = create(:suggestion_category, account: create(:account))
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      alterar(suggestion, { category_id: alheia.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(suggestion.reload.category_id).to be_nil
    end

    # Hora negativa nao e' tempo gasto.
    it 'refuses negative hours' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      alterar(suggestion, { time_spent_hours: '-1' })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(suggestion.reload.time_spent_hours).to be_nil
    end

    it 'accepts zero hours' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      alterar(suggestion, { time_spent_hours: '0' })

      expect(response).to have_http_status(:success)
      expect(suggestion.reload.time_spent_hours).to eq(0)
    end
  end
end
