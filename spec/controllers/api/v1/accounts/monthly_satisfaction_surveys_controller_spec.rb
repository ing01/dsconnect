require 'rails_helper'

# A avaliacao mensal, do lado interno - so LEITURA. Quem grava e o Portal; a
# equipe so consulta o resultado.
RSpec.describe 'Monthly satisfaction surveys API', type: :request do
  let(:account) { create(:account) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:empresa) { create(:company, account: account) }
  let(:outra_empresa) { create(:company, account: account) }
  let(:contato) { create(:contact, account: account, company: empresa) }

  def avaliacao(atributos = {})
    create(:monthly_satisfaction_survey, { account: account, company: empresa, contact: contato }.merge(atributos))
  end

  def listar(params = {}, user: agente)
    get "/api/v1/accounts/#{account.id}/monthly_satisfaction_surveys",
        params: params, headers: user.create_new_auth_token, as: :json
  end

  describe 'GET index' do
    it 'refuses an unauthenticated caller' do
      get "/api/v1/accounts/#{account.id}/monthly_satisfaction_surveys"

      expect(response).to have_http_status(:unauthorized)
    end

    # Transparencia: qualquer agente le, como as Manifestacoes.
    it 'lists for a plain agent' do
      avaliacao

      listar

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].size).to eq(1)
    end

    it 'does not list another account survey' do
      outra_conta = create(:account)
      create(:monthly_satisfaction_survey, account: outra_conta, company: create(:company, account: outra_conta))

      listar

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'filters by company' do
      avaliacao(company: empresa)
      avaliacao(company: outra_empresa, contact: create(:contact, account: account, company: outra_empresa))

      listar({ company_id: empresa.id })

      expect(response.parsed_body['payload'].map { |item| item['company_id'] }).to eq([empresa.id])
    end

    it 'filters by reference_month' do
      avaliacao(reference_month: Date.new(2026, 9, 1))
      avaliacao(reference_month: Date.new(2026, 10, 1), contact: create(:contact, account: account, company: empresa))

      listar({ reference_month: '2026-10-01' })

      expect(response.parsed_body['payload'].size).to eq(1)
      expect(response.parsed_body['payload'].first['reference_month']).to eq('2026-10-01')
    end

    # A base da futura tela de resultados: media geral e media por pergunta,
    # ja calculadas no servidor.
    it 'computes the overall average and the average per question' do
      primeira = avaliacao
      primeira.answers.each { |resposta| resposta.update!(rating: 2) }
      segunda = avaliacao(contact: create(:contact, account: account, company: empresa))
      segunda.answers.each { |resposta| resposta.update!(rating: 4) }

      listar

      meta = response.parsed_body['meta']
      expect(meta['count']).to eq(2)
      expect(meta['average_rating']).to eq(3.0)
      expect(meta['average_by_question']['erp_overall']).to eq(3.0)
    end

    it 'does not blow up when there are no surveys yet' do
      listar

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['meta']['average_rating']).to be_nil
    end
  end

  describe 'GET show' do
    it 'shows one survey with its ten answers' do
      registro = avaliacao(comment: 'Gostaria de mais agilidade.')

      get "/api/v1/accounts/#{account.id}/monthly_satisfaction_surveys/#{registro.id}",
          headers: agente.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['comment']).to eq('Gostaria de mais agilidade.')
      expect(response.parsed_body['answers'].size).to eq(10)
      expect(response.parsed_body['contact_name']).to eq(contato.name)
    end

    it 'does not reach a survey from another account' do
      outra_conta = create(:account)
      alheia = create(:monthly_satisfaction_survey, account: outra_conta, company: create(:company, account: outra_conta))

      get "/api/v1/accounts/#{account.id}/monthly_satisfaction_surveys/#{alheia.id}",
          headers: agente.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
