require 'rails_helper'

# A comunicacao com o cliente pela API. O `closing` distingue a correspondencia
# comum da notificacao de encerramento - e so a de encerramento libera o
# fechamento do ticket.
RSpec.describe 'Ticket customer communication', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  let(:contato) { create(:contact, account: account, email: 'cliente@exemplo.com.br') }
  let(:ticket) do
    create(:ticket, account: account, team: team, ticket_column: column, contact: contato)
  end

  def enviar(params)
    post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/customer_communications",
         params: params, headers: administrator.create_new_auth_token, as: :json
  end

  # A tela sempre manda o campo; quem chama a API direto nao. Sem o padrao, o
  # nil atropelava o default da coluna NOT NULL e a resposta trazia o erro cru
  # do Postgres em vez de uma comunicacao enviada.
  it 'treats a missing closing flag as ordinary correspondence' do
    enviar({ body: 'Segue o retorno solicitado.' })

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['closing']).to be(false)
    expect(ticket.ticket_customer_communications.last.closing).to be(false)
  end

  it 'records a closing notice when asked for one' do
    enviar({ body: 'Seu atendimento foi concluido.', closing: true })

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['closing']).to be(true)
  end

  # Sem e-mail do solicitante nao ha para onde enviar, e a recusa precisa dizer
  # isso - nao falhar na entrega depois de gravar.
  it 'refuses when the requester has no e-mail, before creating anything' do
    contato.update!(email: nil)

    expect { enviar({ body: 'Teste' }) }
      .not_to(change { ticket.ticket_customer_communications.count })
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['code']).to eq('contact_email_missing')
  end

  # O flag de envio. Registrar sem e-mail existe para quando a equipe ja falou
  # com o cliente por telefone ou WhatsApp e quer deixar isso no chamado.
  describe 'the e-mail flag' do
    it 'sends no mail when the caller asks not to' do
      expect { enviar({ body: 'Falei com voce por telefone.', notify_customer: false }) }
        .not_to(change { ActionMailer::Base.deliveries.count })

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['status']).to eq('skipped')
      expect(response.parsed_body['notify_customer']).to be(false)
    end

    # O default nao pode virar "nao envie": quem chama a API sem conhecer o campo
    # - e toda integracao que existia antes dele - continua enviando.
    it 'sends when nobody says anything about it' do
      enviar({ body: 'Segue o retorno solicitado.' })

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['notify_customer']).to be(true)
      expect(response.parsed_body['status']).to eq('sent')
    end

    # `"false"` em vez de `false`: e o que chega de um formulario, e tratar isso
    # como verdadeiro enviaria o e-mail que a pessoa pediu para nao enviar.
    it 'understands the string form' do
      enviar({ body: 'Registro apenas.', notify_customer: 'false' })

      expect(response.parsed_body['notify_customer']).to be(false)
    end
  end
end
