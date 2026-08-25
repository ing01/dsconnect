require 'rails_helper'

RSpec.describe 'Ticket detail payload', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:ticket_column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, account: account, ticket_column: ticket_column, team: team) }

  def show_ticket(as: agent)
    get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
        headers: as.create_new_auth_token,
        as: :json
    response.parsed_body
  end

  describe 'requester' do
    it 'exposes the contact of the earliest linked conversation' do
      contact = create(:contact, account: account, name: 'Renan', email: 'renan@acme.test', phone_number: '+551899999999')
      conversation = create(:conversation, account: account, contact: contact)
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      body = show_ticket

      expect(body['contact']).to include(
        'id' => contact.id, 'name' => 'Renan',
        'email' => 'renan@acme.test', 'phone_number' => '+551899999999'
      )
      expect(body['requester_name']).to eq('Renan')
    end

    it 'is null when nothing is linked' do
      expect(show_ticket['contact']).to be_nil
    end

    it 'picks the earliest conversation, not an arbitrary one' do
      first = create(:conversation, account: account, contact: create(:contact, account: account, name: 'Primeiro'))
      second = create(:conversation, account: account, contact: create(:contact, account: account, name: 'Segundo'))
      create(:ticket_conversation, ticket: ticket, conversation: second)
      create(:ticket_conversation, ticket: ticket, conversation: first)

      expect(show_ticket['contact']['name']).to eq('Primeiro')
    end
  end

  describe 'conversations' do
    it 'carries display_id for navigation alongside the internal id' do
      create(:conversation, account: account)
      conversation = create(:conversation, account: account)
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      entry = show_ticket['conversations'].first

      expect(entry['id']).to eq(conversation.id)
      expect(entry['display_id']).to eq(conversation.display_id)
      # The regression this pins: the dashboard router resolves by display_id.
      expect(entry['display_id']).not_to eq(entry['id'])
    end

    it 'exposes the channel of the conversation inbox' do
      conversation = create(:conversation, account: account)
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      expect(show_ticket['conversations'].first['channel']).to eq(conversation.inbox.channel_type)
    end
  end

  describe 'created_by' do
    it 'comes from the created activity actor' do
      ticket.ticket_activities.find_by(activity_type: :created).update!(user: administrator)

      expect(show_ticket['created_by']).to include('id' => administrator.id, 'name' => administrator.name)
    end

    it 'is null when the ticket was created without an acting user' do
      expect(show_ticket['created_by']).to be_nil
    end
  end

  describe 'can_update' do
    it 'is true for an administrator' do
      expect(show_ticket(as: administrator)['can_update']).to be(true)
    end

    it 'is false for an agent who is neither assignee nor Mesa member' do
      expect(show_ticket['can_update']).to be(false)
    end

    it 'is true for a member of the ticket Mesa' do
      team.add_members([agent.id])

      expect(show_ticket['can_update']).to be(true)
    end
  end

  # The detail fields must never leak onto the hot paths: the board inlines
  # every ticket of every column, and the list is paginated but wide.
  describe 'leanness of the list and board payloads' do
    let(:detail_only_keys) { %w[contact conversations created_by attachments can_update] }

    it 'keeps them out of GET /tickets' do
      ticket
      get "/api/v1/accounts/#{account.id}/tickets", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].first.keys).not_to include(*detail_only_keys)
    end

    it 'keeps them out of the Kanban board' do
      ticket
      get "/api/v1/accounts/#{account.id}/teams/#{team.id}", headers: agent.create_new_auth_token, as: :json

      board_ticket = response.parsed_body['ticket_columns'].flat_map { |column| column['tickets'] }.first
      expect(board_ticket.keys).not_to include(*detail_only_keys)
    end
  end

  describe 'the other single-record endpoints' do
    it 'returns the detail payload on update too, so the SPA never loses it' do
      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
            params: { ticket: { title: 'Novo titulo' } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response.parsed_body).to have_key('conversations')
      expect(response.parsed_body).to have_key('contact')
    end
  end
end
