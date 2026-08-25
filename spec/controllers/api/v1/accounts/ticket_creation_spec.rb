require 'rails_helper'

# The single creation contract behind the Kanban, the chat and the child flow.
# Every rule here is enforced server-side, not only by the form.
RSpec.describe 'Ticket creation', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:category) { team.ticket_categories.first }
  let(:company) { create(:company, account: account) }
  let(:contact) { create(:contact, account: account, company: company) }

  def valid_params(extra = {})
    { title: 'Erro na emissao de NF', description: 'detalhes', priority: 'high',
      company_id: company.id, contact_id: contact.id,
      team_id: team.id, ticket_column_id: column.id,
      ticket_category_id: category.id }.merge(extra)
  end

  def create_ticket(attributes = valid_params, extra = {})
    post "/api/v1/accounts/#{account.id}/tickets",
         params: { ticket: attributes }.merge(extra),
         headers: administrator.create_new_auth_token, as: :json
  end

  it 'opens a ticket with everything the form collected' do
    create_ticket

    expect(response).to have_http_status(:success)
    ticket = Ticket.find(response.parsed_body['id'])
    expect(ticket).to have_attributes(
      title: 'Erro na emissao de NF', priority: 'high',
      company_id: company.id, contact_id: contact.id,
      team_id: team.id, ticket_column_id: column.id, ticket_category_id: category.id
    )
  end

  # Status is not part of the form: a new ticket is always open, and the
  # Kanban only shows open ones.
  it 'always starts open' do
    create_ticket

    expect(Ticket.find(response.parsed_body['id']).status).to eq('open')
  end

  describe 'required fields' do
    { title: '', description: '', priority: nil, ticket_category_id: nil }.each do |field, blank|
      it "refuses a ticket without #{field}" do
        expect { create_ticket(valid_params(field => blank)) }.not_to change(Ticket, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'the Mesa owns its own lists' do
    let(:other_team) { create(:team, account: account) }

    it 'refuses a Categoria from another Mesa' do
      create_ticket(valid_params(ticket_category_id: other_team.ticket_categories.first.id))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses an Estagio from another Mesa' do
      create_ticket(valid_params(ticket_column_id: create(:ticket_column, team: other_team).id))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a Responsavel who is not a member of the Mesa' do
      outsider = create(:user, account: account, role: :agent)

      create_ticket(valid_params(assignee_id: outsider.id))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'accepts one who is' do
      member = create(:user, account: account, role: :agent)
      team.add_members([member.id])

      create_ticket(valid_params(assignee_id: member.id))

      expect(Ticket.find(response.parsed_body['id']).assignee).to eq(member)
    end
  end

  it 'refuses a Solicitante who does not belong to the Empresa' do
    outsider = create(:contact, account: account, company: create(:company, account: account))

    create_ticket(valid_params(contact_id: outsider.id))

    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe 'followers' do
    it 'records them without confusing them with the Responsavel' do
      watcher = create(:user, account: account, role: :agent)

      create_ticket(valid_params(follower_ids: [watcher.id]))

      ticket = Ticket.find(response.parsed_body['id'])
      expect(ticket.followers).to eq([watcher])
      expect(ticket.assignee_id).to be_nil
    end
  end

  describe 'the parent ticket' do
    it 'links the new ticket to the chosen parent' do
      parent = create(:ticket, account: account, ticket_column: column, team: team)

      create_ticket(valid_params(parent_id: parent.id))

      expect(Ticket.find(response.parsed_body['id']).parent).to eq(parent)
    end
  end

  describe 'opened from a conversation' do
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, contact: contact, inbox: inbox) }

    # Related, never duplicated: `ticket_conversations` is a join table.
    it 'links the conversation without copying a single message' do
      create(:message, account: account, conversation: conversation)

      expect { create_ticket(valid_params, conversation_id: conversation.id) }
        .to not_change(Message, :count).and not_change(Conversation, :count)

      expect(Ticket.find(response.parsed_body['id']).conversations).to eq([conversation])
    end

    it 'leaves the conversation open' do
      create_ticket(valid_params, conversation_id: conversation.id)

      expect(conversation.reload.status).to eq('open')
    end

    # A ticket can gather several conversations; linking one never replaces
    # what is already there.
    it 'adds to the conversations a ticket already has' do
      ticket = create(:ticket, account: account, ticket_column: column, team: team)
      first = create(:conversation, account: account, contact: contact)
      ticket.ticket_conversations.create!(account_id: account.id, conversation: first)

      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/ticket_conversations",
           params: { ticket_conversation: { conversation_id: conversation.id } },
           headers: administrator.create_new_auth_token, as: :json

      expect(ticket.reload.conversations).to contain_exactly(first, conversation)
    end
  end

  describe 'the history' do
    it 'records one creation entry carrying the opening state' do
      create_ticket(valid_params)
      ticket = Ticket.find(response.parsed_body['id'])

      activities = ticket.ticket_activities
      expect(activities.count).to eq(1)

      meta = activities.first.meta
      expect(activities.first.user).to eq(administrator)
      expect(meta).to include(
        'company_id' => company.id, 'contact_id' => contact.id,
        'team_id' => team.id, 'ticket_column_id' => column.id,
        'ticket_category_id' => category.id, 'priority' => 'high'
      )
    end

    it 'records a manual origin when no chat is involved' do
      create_ticket

      expect(Ticket.find(response.parsed_body['id'])
                   .ticket_activities.first.meta['origin']).to eq('manual')
    end

    it 'records the channel when the ticket came from a chat' do
      inbox = create(:inbox, account: account)
      conversation = create(:conversation, account: account, contact: contact, inbox: inbox)

      create_ticket(valid_params, conversation_id: conversation.id)

      expect(Ticket.find(response.parsed_body['id'])
                   .ticket_activities.first.meta['origin']).to eq(inbox.channel_type)
    end
  end

  describe 'categories' do
    it 'gives a new Mesa a usable list, so a ticket can be opened in it' do
      fresh = create(:team, account: account)

      expect(fresh.ticket_categories).to be_present
    end

    it 'lists them for the Mesa' do
      get "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_categories",
          headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('name')).to eq(team.ticket_categories.ordered.pluck(:name))
    end

    it 'refuses to delete one that still has tickets' do
      create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category)

      delete "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_categories/#{category.id}",
             headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(category.reload).to be_present
    end

    # Only admins shape the list; every agent needs to read it to open a ticket.
    it 'refuses creation by a plain agent' do
      agent = create(:user, account: account, role: :agent)

      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_categories",
           params: { ticket_category: { name: 'Nova' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # Categories belong to a Mesa, so a ticket that moves to another one cannot
  # keep the category it had - otherwise every cross-Mesa move would be invalid.
  describe 'moving between Mesas' do
    it 'drops the category rather than blocking the move' do
      other_team = create(:team, account: account)
      other_column = create(:ticket_column, team: other_team)
      ticket = create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category)

      ticket.move_to!(ticket_column: other_column, position: 0)

      expect(ticket.reload.team).to eq(other_team)
      expect(ticket.ticket_category_id).to be_nil
    end
  end
end
