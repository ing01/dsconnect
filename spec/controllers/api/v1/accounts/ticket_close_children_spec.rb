require 'rails_helper'

# Finalizar os tickets filhos junto com o pai, com a Resolucao, a classificacao e a
# comunicacao dele.
RSpec.describe 'Ticket close children API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:category) { create(:ticket_category, team: team) }
  let(:catalog_item) do
    catalog = create(:service_catalog, account: account)
    create(:service_catalog_item, service_catalog_area: create(:service_catalog_area, service_catalog: catalog))
  end
  let(:contact) { create(:contact, account: account, email: 'cliente@exemplo.com') }
  let(:parent) { ticket(resolution: 'Ajustado o cadastro.', service_catalog_item: catalog_item) }

  def ticket(**attrs)
    create(:ticket, account: account, team: team, ticket_column: column, ticket_category: category, contact: contact, **attrs)
  end

  def close_parent_with_message
    parent.ticket_customer_communications.create!(
      user: admin, contact: contact, to_email: contact.email, subject: 'Encerramento',
      body: '<p>Resolvido</p>', direction: 'outbound', closing: true, status: 'sent'
    )
    parent.close!(admin)
  end

  def close_children(user = admin)
    post "/api/v1/accounts/#{account.id}/tickets/#{parent.id}/close_children",
         headers: user.create_new_auth_token, as: :json
  end

  it 'closes the child with the data of the parent' do
    child = ticket(parent: parent)
    close_parent_with_message

    close_children

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['closed']).to eq([child.display_id])
    child.reload
    expect(child).to be_closed
    expect(child.resolution).to eq('Ajustado o cadastro.')
    expect(child.service_catalog_item).to eq(catalog_item)
    # Registrada sem e-mail: o cliente ja recebeu pelo pai.
    expect(child.ticket_customer_communications.sole)
      .to have_attributes(body: '<p>Resolvido</p>', status: 'skipped', closing: true)
  end

  it 'keeps what the child already had' do
    child = ticket(parent: parent, resolution: 'Corrigido o calculo.')
    close_parent_with_message

    close_children

    expect(child.reload.resolution).to eq('Corrigido o calculo.')
  end

  it 'reports a child that cannot be closed and leaves nothing copied on it' do
    child = ticket(parent: parent)
    # A categoria e' exigida na abertura; um ticket antigo ou importado pode nao ter.
    child.update_column(:ticket_category_id, nil) # rubocop:disable Rails/SkipsModelValidations
    close_parent_with_message

    close_children

    expect(response.parsed_body['pending']).to eq([{ 'display_id' => child.display_id, 'missing' => ['ticket_category'] }])
    child.reload
    expect(child).not_to be_closed
    expect(child.resolution).to be_blank
    expect(child.service_catalog_item).to be_nil
    expect(child.ticket_customer_communications).to be_empty
  end

  it 'does not close children while the parent is open' do
    child = ticket(parent: parent)

    close_children

    expect(response).to have_http_status(:unprocessable_entity)
    expect(child.reload).not_to be_closed
  end

  it 'is refused to someone outside the ticket team' do
    child = ticket(parent: parent)
    close_parent_with_message

    close_children(create(:user, account: account, role: :agent))

    expect(response).to have_http_status(:unauthorized)
    expect(child.reload).not_to be_closed
  end
end
