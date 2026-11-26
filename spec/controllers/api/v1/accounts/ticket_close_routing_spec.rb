require 'rails_helper'

# Fechar escolhendo Categoria, Mesa e Estagio (dialogo "Fechar ticket").
RSpec.describe 'Ticket close with routing', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:support) { create(:team, account: account, name: 'suporte') }
  let(:specialist) { create(:team, account: account, name: 'especialista') }
  let(:support_column) { create(:ticket_column, team: support) }
  let(:specialist_column) { create(:ticket_column, team: specialist) }
  let(:support_category) { create(:ticket_category, team: support) }
  let(:specialist_category) { create(:ticket_category, team: specialist) }
  let(:catalog_item) do
    catalog = create(:service_catalog, account: account)
    create(:service_catalog_item, service_catalog_area: create(:service_catalog_area, service_catalog: catalog))
  end
  let(:ticket) do
    create(:ticket, account: account, team: support, ticket_column: support_column,
                    ticket_category: support_category, service_catalog_item: catalog_item)
  end

  def transfer(attributes)
    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/transfer",
          params: { ticket: attributes.merge(status: 'closed', resolution: 'corrigido') },
          headers: admin.create_new_auth_token, as: :json
  end

  it 'closes with a category of the Mesa the ticket is going to' do
    transfer(team_id: specialist.id, ticket_column_id: specialist_column.id, ticket_category_id: specialist_category.id)

    expect(response).to have_http_status(:success)
    expect(ticket.reload).to have_attributes(status: 'closed', team_id: specialist.id,
                                             ticket_category_id: specialist_category.id)
  end

  it 'still refuses a category from a Mesa the ticket is not going to' do
    transfer(team_id: support.id, ticket_column_id: support_column.id, ticket_category_id: specialist_category.id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to be_present
    expect(ticket.reload).to be_open
  end

  it 'closes an old ticket whose saved category belongs to another Mesa' do
    ticket.update_column(:ticket_category_id, specialist_category.id) # rubocop:disable Rails/SkipsModelValidations

    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/close",
          params: { resolution: 'corrigido' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(ticket.reload).to be_closed
  end
end
