require 'rails_helper'

# A habilitacao do acesso a Area do Cliente, pelo lado da equipe interna.
#
# Este arquivo existe por um defeito real: a acao passava pelo
# `check_authorization` do controller de contatos, e sem `ContactPolicy#client_access?`
# o Pundit levantava NoMethodError - a tela so dizia "nao foi possivel salvar".
# Os testes da Area do Cliente nao alcancavam isso: eles entram pela API do
# cliente, nunca por esta.
RSpec.describe 'Contact client access', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:empresa) { create(:company, account: account) }
  let(:contato) { create(:contact, account: account, email: 'cliente@exemplo.com.br', company: empresa) }

  def habilitar(params, user: administrator)
    patch "/api/v1/accounts/#{account.id}/contacts/#{contato.id}/client_access",
          params: params, headers: user.create_new_auth_token, as: :json
  end

  it 'enables the access and stores the credentials' do
    habilitar({ enabled: true, password: 'SenhaDoCliente@01', tickets_visibility: 'company' })

    expect(response).to have_http_status(:success)
    contato.reload
    expect(contato.client_access?).to be(true)
    expect(contato.valid_password?('SenhaDoCliente@01')).to be(true)
    expect(contato.client_tickets_visibility).to eq('company')
  end

  it 'answers with the contact carrying the access state' do
    habilitar({ enabled: true, password: 'SenhaDoCliente@01' })

    # A resposta e a do `show` do contato, que embrulha em `payload`.
    body = response.parsed_body['payload']
    expect(body['client_access_enabled']).to be(true)
    expect(body['client_access_ready']).to be(true)
    expect(body['client_tickets_visibility']).to eq('own')
  end

  # Ligar sem senha, num contato que nunca teve uma, nao pode passar: acesso
  # sem credencial nao e acesso.
  it 'refuses to enable without a password on the first time' do
    habilitar({ enabled: true })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(contato.reload.client_access?).to be(false)
  end

  it 'keeps the previous password when re-enabling without one' do
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato.disable_client_access!

    habilitar({ enabled: true })

    expect(response).to have_http_status(:success)
    expect(contato.reload.valid_password?('SenhaDoCliente@01')).to be(true)
  end

  it 'disables the access and revokes the open session' do
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato.client_access_token

    habilitar({ enabled: false })

    expect(response).to have_http_status(:success)
    contato.reload
    expect(contato.client_access_enabled).to be(false)
    expect(contato.access_token).to be_nil
  end

  # Emitir credencial de login para alguem de fora e decisao de administrador.
  it 'refuses a plain agent' do
    habilitar({ enabled: true, password: 'SenhaDoCliente@01' }, user: agente)

    expect(response).to have_http_status(:unauthorized)
    expect(contato.reload.client_access?).to be(false)
  end
end
