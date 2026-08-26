require 'rails_helper'

# Closing a ticket has to mean a finished, classified attendance: the customer
# was told, and the work was filed under the service catalogue. Both rules are
# enforced in the model, so every path that closes on an agent's behalf hits
# them - not just the button.
RSpec.describe 'Ticket closing requirements', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:company) { create(:company, account: account) }
  let(:contact) { create(:contact, account: account, company: company, email: 'renan@empresa.com') }
  let(:catalog) { create(:service_catalog, account: account, name: 'DS Comercial') }
  let(:area) { create(:service_catalog_area, service_catalog: catalog, name: 'Movimentações') }
  let(:item) { create(:service_catalog_item, service_catalog_area: area, name: 'Notas Fiscais de Mercadorias') }

  let(:ticket) do
    create(:ticket, account: account, ticket_column: column, team: team,
                    company: company, contact: contact)
  end

  def auth
    administrator.create_new_auth_token
  end

  def close_ticket
    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/close", headers: auth, as: :json
  end

  def send_communication(params = {})
    post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/customer_communications",
         params: { subject: 'Encerramento', body: '<p>Resolvido</p>', closing: true }.merge(params),
         headers: auth, as: :json
  end

  def classify(item_record = item)
    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/classify",
          params: { service_catalog_id: item_record.service_catalog.id,
                    service_catalog_area_id: item_record.service_catalog_area_id,
                    service_catalog_item_id: item_record.id },
          headers: auth, as: :json
  end

  # A message that genuinely went out, without going through the mailer.
  def record_sent_communication(closing: true)
    ticket.ticket_customer_communications.create!(
      account_id: account.id, user: administrator, contact: contact,
      to_email: contact.email, subject: 'Encerramento', body: 'texto',
      closing: closing, status: 'sent', sent_at: Time.zone.now
    )
  end

  describe 'the Categoria requirement' do
    # Categoria and Catalogo de Servicos are different classifications; both are
    # required and neither substitutes the other.
    it 'refuses to close a ticket without a Categoria' do
      ticket.update_column(:ticket_category_id, nil) # rubocop:disable Rails/SkipsModelValidations
      ticket.update!(service_catalog_item: item)
      record_sent_communication

      close_ticket

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['missing']).to eq(['ticket_category'])
      expect(ticket.reload.status).to eq('open')
    end

    it 'closes once a Categoria is set, with everything else in place' do
      ticket.update_column(:ticket_category_id, nil) # rubocop:disable Rails/SkipsModelValidations
      ticket.update!(service_catalog_item: item)
      record_sent_communication

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
            params: { ticket: { ticket_category_id: team.ticket_categories.first.id } },
            headers: auth, as: :json
      close_ticket

      expect(response).to have_http_status(:success)
      expect(ticket.reload.status).to eq('closed')
    end

    it 'refuses a Categoria that belongs to another Mesa' do
      other_team = create(:team, account: account)

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
            params: { ticket: { ticket_category_id: other_team.ticket_categories.first.id } },
            headers: auth, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'records the change in the history' do
      target = team.ticket_categories.last

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
            params: { ticket: { ticket_category_id: target.id } },
            headers: auth, as: :json

      activity = ticket.ticket_activities.where(activity_type: :category_changed).last
      expect(activity.new_value).to eq(target.id.to_s)
      expect(activity.user).to eq(administrator)
    end
  end

  describe 'without the requirements' do
    it 'refuses to close a ticket with neither' do
      close_ticket

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.status).to eq('open')
    end

    it 'says exactly what is missing' do
      close_ticket

      expect(response.parsed_body['missing']).to include('service_catalog', 'customer_communication')
    end

    it 'refuses when only the classification is there' do
      ticket.update!(service_catalog_item: item)

      close_ticket

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['missing']).to eq(['customer_communication'])
      expect(ticket.reload.status).to eq('open')
    end

    it 'refuses when only the communication is there' do
      record_sent_communication

      close_ticket

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['missing']).to eq(['service_catalog'])
      expect(ticket.reload.status).to eq('open')
    end

    # A message that was written but never left does not count.
    it 'does not accept a failed communication' do
      ticket.update!(service_catalog_item: item)
      ticket.ticket_customer_communications.create!(
        account_id: account.id, user: administrator, contact: contact,
        to_email: contact.email, subject: 'x', body: 'y', closing: true, status: 'failed'
      )

      close_ticket

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.status).to eq('open')
    end

    # Only a closing message satisfies the rule; ordinary correspondence does not.
    it 'does not accept a non-closing communication' do
      ticket.update!(service_catalog_item: item)
      record_sent_communication(closing: false)

      close_ticket

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'with both requirements' do
    it 'closes the ticket' do
      ticket.update!(service_catalog_item: item)
      record_sent_communication

      close_ticket

      expect(response).to have_http_status(:success)
      ticket.reload
      expect(ticket.status).to eq('closed')
      expect(ticket.closed_at).to be_present
    end

    it 'records the close in the history' do
      ticket.update!(service_catalog_item: item)
      record_sent_communication

      close_ticket

      expect(ticket.ticket_activities.find_by(activity_type: :closed).user).to eq(administrator)
    end

    # The rule established earlier: terminal tickets leave the operational board.
    it 'takes the ticket off the Kanban' do
      ticket.update!(service_catalog_item: item)
      record_sent_communication
      close_ticket

      get "/api/v1/accounts/#{account.id}/teams/#{team.id}", headers: auth, as: :json

      board_ids = response.parsed_body['ticket_columns'].flat_map { |c| c['tickets'] }.pluck('id')
      expect(board_ids).not_to include(ticket.id)
    end

    it 'keeps it findable through the detailed search' do
      ticket.update!(service_catalog_item: item)
      record_sent_communication
      close_ticket

      get "/api/v1/accounts/#{account.id}/tickets", params: { status: 'closed' }, headers: auth, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to include(ticket.id)
    end
  end

  # A requester with no address cannot be told anything, so saying so up front
  # beats failing at send time.
  describe 'when the requester has no e-mail' do
    let(:contact) { create(:contact, account: account, company: company, email: nil) }

    it 'lists it as a blocker' do
      ticket.update!(service_catalog_item: item)

      close_ticket

      expect(response.parsed_body['missing']).to include('contact_email')
      expect(ticket.reload.status).to eq('open')
    end

    it 'refuses to send a communication' do
      send_communication

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('contact_email_missing')
      expect(ticket.ticket_customer_communications).to be_empty
    end
  end

  describe 'classification' do
    it 'stores only the Item and reaches the two levels above it' do
      classify

      expect(response).to have_http_status(:success)
      ticket.reload
      expect(ticket.service_catalog_item).to eq(item)
      expect(ticket.service_catalog_item.full_path)
        .to eq(['DS Comercial', 'Movimentações', 'Notas Fiscais de Mercadorias'])
    end

    it 'records the full path in the history' do
      classify

      activity = ticket.ticket_activities.find_by(activity_type: :classified)
      expect(activity.new_value).to eq('DS Comercial > Movimentações > Notas Fiscais de Mercadorias')
      expect(activity.user).to eq(administrator)
    end

    # The hierarchy is walked server-side, so a mismatched trio is refused even
    # though every id exists.
    it 'refuses an Area that belongs to another Catalogo' do
      other_area = create(:service_catalog_area, service_catalog: create(:service_catalog, account: account))

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/classify",
            params: { service_catalog_id: catalog.id, service_catalog_area_id: other_area.id,
                      service_catalog_item_id: item.id },
            headers: auth, as: :json

      expect(response).to have_http_status(:not_found)
      expect(ticket.reload.service_catalog_item).to be_nil
    end

    it 'refuses an Item that belongs to another Area' do
      other_item = create(:service_catalog_item,
                          service_catalog_area: create(:service_catalog_area, service_catalog: catalog))

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/classify",
            params: { service_catalog_id: catalog.id, service_catalog_area_id: area.id,
                      service_catalog_item_id: other_item.id },
            headers: auth, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a catalogue from another account' do
      foreign = create(:service_catalog, account: create(:account))

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/classify",
            params: { service_catalog_id: foreign.id, service_catalog_area_id: area.id,
                      service_catalog_item_id: item.id },
            headers: auth, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # Grouping is an administrative close, not a finished attendance, so it is the
  # one path that bypasses the requirements.
  describe 'grouping a ticket' do
    it 'closes the merged ticket without a catalogue or a communication' do
      survivor = create(:ticket, account: account, ticket_column: column, team: team)

      post "/api/v1/accounts/#{account.id}/tickets/#{survivor.id}/merge",
           params: { source_id: ticket.id }, headers: auth, as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.status).to eq('closed')
      expect(ticket.close_reason).to eq('merged')
    end
  end
end
