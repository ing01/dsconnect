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
end
