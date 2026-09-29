require 'rails_helper'

# As duas listas configuraveis do quadro de Sugestoes: Prioridade e Categoria.
# Sao a mesma forma - nome por conta, sem reordenar -, entao um spec so cobre as
# duas em paralelo: qualquer divergencia entre elas aparece aqui.
RSpec.describe 'Suggestion configurable lists', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  # [rota, fabrica, chave do corpo, associacao na sugestao]
  listas = [
    ['suggestion_priorities', :suggestion_priority, :suggestion_priority, :priority],
    ['suggestion_categories', :suggestion_category, :suggestion_category, :category]
  ].freeze

  listas.each do |rota, fabrica, chave, associacao|
    describe rota do
      let(:base) { "/api/v1/accounts/#{account.id}/#{rota}" }

      it 'refuses an unauthenticated caller' do
        get base

        expect(response).to have_http_status(:unauthorized)
      end

      # O agente comum PRECISA ler a lista: ela alimenta o select do quadro e do
      # formulario de sugestao. Ler nao e configurar.
      it 'lists for a plain agent' do
        create(fabrica, account: account, name: 'Alta')

        get base, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.map { |item| item['name'] }).to eq(['Alta'])
      end

      # A lista e da conta. Sem este corte, o select de um cliente mostraria os
      # nomes que outro cadastrou.
      it 'does not list another account items' do
        create(fabrica, account: create(:account), name: 'De outra conta')

        get base, headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body).to be_empty
      end

      it 'orders by position, which follows the order they were created' do
        create(fabrica, account: account, name: 'Primeira')
        create(fabrica, account: account, name: 'Segunda')

        get base, headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body.map { |item| item['name'] }).to eq(%w[Primeira Segunda])
      end

      it 'lets an administrator create one' do
        post base, params: { chave => { name: 'Urgente' } },
                   headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(account.public_send(rota).pluck(:name)).to eq(['Urgente'])
      end

      # Configurar a lista e' do administrador; o agente comum apenas a le.
      it 'forbids a plain agent from creating one' do
        post base, params: { chave => { name: 'Urgente' } },
                   headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(account.public_send(rota).count).to eq(0)
      end

      it 'refuses a nameless item' do
        post base, params: { chave => { name: '' } },
                   headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'lets an administrator rename one' do
        item = create(fabrica, account: account, name: 'Media')

        patch "#{base}/#{item.id}", params: { chave => { name: 'Normal' } },
                                    headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(item.reload.name).to eq('Normal')
      end

      it 'forbids a plain agent from renaming one' do
        item = create(fabrica, account: account, name: 'Media')

        patch "#{base}/#{item.id}", params: { chave => { name: 'Normal' } },
                                    headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(item.reload.name).to eq('Media')
      end

      it 'does not reach an item of another account' do
        alheio = create(fabrica, account: create(:account))

        patch "#{base}/#{alheio.id}", params: { chave => { name: 'Invadida' } },
                                      headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:not_found)
      end

      it 'lets an administrator delete one' do
        item = create(fabrica, account: account)

        delete "#{base}/#{item.id}", headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(account.public_send(rota).count).to eq(0)
      end

      it 'forbids a plain agent from deleting one' do
        item = create(fabrica, account: account)

        delete "#{base}/#{item.id}", headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(item.reload).to be_present
      end

      # O ponto mais sensivel das duas listas: a chave estrangeira existe no
      # banco, entao apagar um item EM USO estouraria se o model nao desmarcasse
      # as sugestoes antes. A sugestao sobrevive sem o campo; nada e perdido.
      it 'unmarks the suggestions instead of blowing up when the item is in use' do
        item = create(fabrica, account: account)
        column = create(:suggestion_column, account: account)
        suggestion = create(:suggestion, { :account => account, :suggestion_column => column,
                                           associacao => item })

        delete "#{base}/#{item.id}", headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(suggestion.reload).to be_present
        expect(suggestion.public_send("#{associacao}_id")).to be_nil
      end
    end
  end
end
