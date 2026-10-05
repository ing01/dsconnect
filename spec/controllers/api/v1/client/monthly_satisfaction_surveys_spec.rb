require 'rails_helper'

# A avaliacao mensal de satisfacao, pela Area do Cliente.
#
# O que se prova aqui e o SIGILO ("so posso ver/responder a MINHA") e a trava
# de uma por mes - e e' o SERVIDOR quem recusa a segunda tentativa, nunca so
# a tela.
RSpec.describe 'Client monthly satisfaction survey', type: :request do
  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }

  let(:cliente) do
    contato = create(:contact, account: account, email: 'cliente@exemplo.com.br', company: empresa)
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato
  end

  let(:colega) { create(:contact, account: account, email: 'colega@exemplo.com.br', company: empresa) }

  def entrar(email: 'cliente@exemplo.com.br')
    cliente
    post '/api/v1/client/session',
         params: { email: email, password: 'SenhaDoCliente@01' }, as: :json
    response.parsed_body['api_access_token']
  end

  def cabecalho(token = entrar)
    { api_access_token: token }
  end

  def respostas_validas(overrides = {})
    MonthlySatisfactionSurvey::QUESTION_KEYS.index_with { 4 }.merge(overrides)
  end

  def enviar(answers: respostas_validas, comment: nil, token: nil)
    post '/api/v1/client/monthly_satisfaction_survey',
         params: { answers: answers, comment: comment }.compact, headers: cabecalho(token || entrar), as: :json
  end

  describe 'GET show' do
    it 'refuses an unauthenticated caller' do
      get '/api/v1/client/monthly_satisfaction_survey'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'says the current month is unanswered for a contact who never responded' do
      get '/api/v1/client/monthly_satisfaction_survey', headers: cabecalho, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['answered']).to be(false)
    end

    # As DEZ chaves, na ordem - o texto de cada uma mora so no i18n do
    # frontend, nunca no servidor.
    it 'lists the ten fixed question keys' do
      get '/api/v1/client/monthly_satisfaction_survey', headers: cabecalho, as: :json

      expect(response.parsed_body['question_keys']).to eq(MonthlySatisfactionSurvey::QUESTION_KEYS)
    end

    it 'says the month is already answered once the contact has responded' do
      create(:monthly_satisfaction_survey, account: account, contact: cliente)

      get '/api/v1/client/monthly_satisfaction_survey', headers: cabecalho, as: :json

      expect(response.parsed_body['answered']).to be(true)
    end

    # O SIGILO: a resposta de um COLEGA da mesma empresa nao conta como "eu
    # ja respondi".
    it 'does not count a colleague answer as this contact having answered' do
      create(:monthly_satisfaction_survey, account: account, contact: colega)

      get '/api/v1/client/monthly_satisfaction_survey', headers: cabecalho, as: :json

      expect(response.parsed_body['answered']).to be(false)
    end
  end

  describe 'POST create' do
    it 'refuses an unauthenticated caller' do
      post '/api/v1/client/monthly_satisfaction_survey', params: { answers: respostas_validas }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'registers the survey with the ten answers' do
      enviar

      expect(response).to have_http_status(:created)
      avaliacao = MonthlySatisfactionSurvey.last
      expect(avaliacao.contact_id).to eq(cliente.id)
      expect(avaliacao.answers.count).to eq(10)
    end

    # Empresa e mes nao vem do formulario - sao resolvidos no servidor, a
    # partir de quem esta autenticado.
    it 'fills the company and the month from the signed-in contact' do
      enviar

      avaliacao = MonthlySatisfactionSurvey.last
      expect(avaliacao.company_id).to eq(empresa.id)
      expect(avaliacao.reference_month).to eq(MonthlySatisfactionSurvey.current_reference_month)
    end

    it 'keeps the optional comment' do
      enviar(comment: 'Podiam ser mais rapidos no suporte.')

      expect(MonthlySatisfactionSurvey.last.comment).to eq('Podiam ser mais rapidos no suporte.')
    end

    it 'works without a comment' do
      enviar

      expect(MonthlySatisfactionSurvey.last.comment).to be_nil
    end

    # O PONTO CENTRAL do pedido: nao da pra responder duas vezes no mesmo
    # mes, e e' o SERVIDOR quem recusa.
    it 'refuses a second answer in the same month' do
      token = entrar
      enviar(token: token)

      expect { enviar(token: token) }.not_to change(MonthlySatisfactionSurvey, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('already_answered')
    end

    it 'allows answering again in a different month' do
      create(:monthly_satisfaction_survey, account: account, contact: cliente, reference_month: 1.month.ago)

      enviar

      expect(response).to have_http_status(:created)
    end

    it 'refuses when a question is missing' do
      incompletas = respostas_validas.except('erp_overall')

      enviar(answers: incompletas)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('invalid_answers')
      expect(MonthlySatisfactionSurvey.count).to eq(0)
    end

    it 'refuses a rating outside 1..5' do
      enviar(answers: respostas_validas('erp_overall' => 6))

      expect(response).to have_http_status(:unprocessable_entity)
      expect(MonthlySatisfactionSurvey.count).to eq(0)
    end

    # Uma chave que nao e pergunta nenhuma e' simplesmente IGNORADA pelo
    # `permit` de lista fechada - nunca grava, nunca derruba a requisicao.
    it 'ignores an answer for a question that does not exist' do
      enviar(answers: respostas_validas('nao_e_uma_pergunta' => 5))

      expect(response).to have_http_status(:created)
      expect(MonthlySatisfactionSurveyAnswer.exists?(question_key: 'nao_e_uma_pergunta')).to be(false)
    end

    # O SIGILO, no sentido inverso: mandar o id de OUTRO contato no corpo nao
    # muda nada - o controller nunca le esse campo, so' o contato AUTENTICADO.
    it 'ignores a contact_id sent in the body, in favor of whoever is signed in' do
      post '/api/v1/client/monthly_satisfaction_survey',
           params: { contact_id: colega.id, answers: respostas_validas }, headers: cabecalho, as: :json

      expect(MonthlySatisfactionSurvey.last.contact_id).to eq(cliente.id)
      expect(MonthlySatisfactionSurvey.where(contact_id: colega.id)).to be_empty
    end
  end
end
