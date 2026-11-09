require 'rails_helper'

RSpec.describe 'Conversations API', type: :request do
  let(:account) { create(:account) }

  describe 'POST /api/v1/accounts/{account.id}/conversations' do
    let(:agent) { create(:user, account: account, role: :agent) }
    let!(:api_channel) { create(:channel_api, account: account) }
    let!(:inbox) { create(:inbox, channel: api_channel, account: account) }
    let(:contact) { create(:contact, account: account) }

    before { create(:inbox_member, user: agent, inbox: inbox) }

    it 'marks the conversation as agent initiated, so the automation flow skips it' do
      post "/api/v1/accounts/#{account.id}/conversations",
           params: { contact_id: contact.id, inbox_id: inbox.id },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(Conversation.last.additional_attributes['agent_initiated']).to be(true)
    end

    # O cliente que ja esta sendo atendido por OUTRA pessoa nao pode ser chamado de
    # novo: ninguem fala com o mesmo cliente ao mesmo tempo.
    context 'when the contact is already being attended by another agent' do
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let(:other_inbox) { create(:inbox, account: account) }
      let!(:ongoing) do
        create(:conversation, account: account, inbox: other_inbox, contact: contact, status: :open).tap do |conversation|
          conversation.update_columns(assignee_id: other_agent.id) # rubocop:disable Rails/SkipsModelValidations
        end
      end

      def start_conversation
        post "/api/v1/accounts/#{account.id}/conversations",
             params: { contact_id: contact.id, inbox_id: inbox.id },
             headers: agent.create_new_auth_token,
             as: :json
      end

      it 'blocks it, naming who is attending and which conversation' do
        expect { start_conversation }.not_to change(Conversation, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['code']).to eq('contact_in_attendance')
        expect(response.parsed_body['conversation_id']).to eq(ongoing.display_id)
        expect(response.parsed_body['error']).to include(other_agent.name)
      end

      it 'lets the agent who is already attending the contact go on' do
        ongoing.update_columns(assignee_id: agent.id) # rubocop:disable Rails/SkipsModelValidations

        start_conversation

        expect(response).to have_http_status(:success)
      end

      it 'does not block when the ongoing conversation is already resolved' do
        ongoing.update_columns(status: Conversation.statuses[:resolved]) # rubocop:disable Rails/SkipsModelValidations

        start_conversation

        expect(response).to have_http_status(:success)
      end

      it 'does not block when nobody is assigned to the ongoing conversation' do
        ongoing.update_columns(assignee_id: nil) # rubocop:disable Rails/SkipsModelValidations

        start_conversation

        expect(response).to have_http_status(:success)
      end
    end

    # Cliente que ja chamou e espera sem agente: quem inicia a conversa PUXA essa
    # conversa da fila e fica com ela, em vez de abrir uma segunda.
    context 'when the contact is already waiting without an agent' do
      let!(:waiting) { create(:conversation, account: account, inbox: inbox, contact: contact, status: :open) }

      def start_conversation(user = agent, extra = {})
        post "/api/v1/accounts/#{account.id}/conversations",
             params: { contact_id: contact.id, inbox_id: inbox.id }.merge(extra),
             headers: user.create_new_auth_token,
             as: :json
      end

      it 'pulls the waiting conversation instead of creating another one' do
        expect { start_conversation }.not_to change(Conversation, :count)

        expect(response).to have_http_status(:success)
        expect(waiting.reload.assignee_id).to eq(agent.id)
        expect(response.parsed_body['pulled_from_queue']).to be(true)
      end

      it 'does not mark a customer-initiated conversation as agent initiated' do
        start_conversation

        expect(waiting.reload.additional_attributes['agent_initiated']).to be_blank
      end

      it 'takes a conversation still with the bot and opens it' do
        waiting.update_columns(status: Conversation.statuses[:pending]) # rubocop:disable Rails/SkipsModelValidations

        start_conversation

        expect(waiting.reload.status).to eq('open')
        expect(waiting.assignee_id).to eq(agent.id)
      end

      it 'sends the typed message inside the pulled conversation' do
        start_conversation(agent, { message: { content: 'Olá, como posso ajudar?' } })

        expect(waiting.reload.messages.pluck(:content)).to include('Olá, como posso ajudar?')
      end

      context 'when it is in a manual queue' do
        let(:team) { create(:team, account: account) }
        let(:queue) { ServiceQueue.create!(account: account, team: team, name: 'Suporte', distribution_strategy: 'manual') }

        before do
          create(:team_member, team: team, user: agent)
          waiting.update_columns(queue_id: queue.id) # rubocop:disable Rails/SkipsModelValidations
        end

        it 'lets a non-administrator pull it when it is the next in line' do
          start_conversation

          expect(response).to have_http_status(:success)
          expect(waiting.reload.assignee_id).to eq(agent.id)
        end

        it 'keeps the queue order: refuses when someone else is ahead of it' do
          ahead = create(:conversation, account: account, inbox: create(:inbox, account: account),
                                        status: :open, created_at: 1.hour.ago)
          ahead.update_columns(queue_id: queue.id) # rubocop:disable Rails/SkipsModelValidations

          expect { start_conversation }.not_to change(Conversation, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body['code']).to eq('contact_waiting_in_queue')
          expect(waiting.reload.assignee_id).to be_nil
        end

        it 'lets an administrator pull it regardless of the order' do
          admin = create(:user, account: account, role: :administrator)
          create(:inbox_member, user: admin, inbox: inbox)
          ahead = create(:conversation, account: account, inbox: create(:inbox, account: account),
                                        status: :open, created_at: 1.hour.ago)
          ahead.update_columns(queue_id: queue.id) # rubocop:disable Rails/SkipsModelValidations

          start_conversation(admin)

          expect(response).to have_http_status(:success)
          expect(waiting.reload.assignee_id).to eq(admin.id)
        end
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns all conversations with messages' do
        message = create(:message, conversation: conversation, account: account)
        get "/api/v1/accounts/#{account.id}/conversations",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response).to conform_schema(200)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:data][:meta][:all_count]).to eq(1)
        expect(body[:data][:meta].keys).to include(:all_count, :mine_count, :assigned_count, :unassigned_count)
        expect(body[:data][:payload].first[:uuid]).to eq(conversation.uuid)
        expect(body[:data][:payload].first[:messages].first[:id]).to eq(message.id)
      end

      it 'returns conversations with empty messages array for conversations with out messages' do
        get "/api/v1/accounts/#{account.id}/conversations",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:data][:meta][:all_count]).to eq(1)
        expect(body[:data][:payload].first[:messages]).to eq([])
      end

      it 'returns unattended conversations' do
        attended_conversation = create(:conversation, account: account, first_reply_created_at: Time.now.utc)
        # to ensure that waiting since value is populated
        create(:message, message_type: :outgoing, conversation: attended_conversation, account: account)
        unattended_conversation_no_first_reply = create(:conversation, account: account, first_reply_created_at: nil)
        unattended_conversation_waiting_since = create(:conversation, account: account, first_reply_created_at: Time.now.utc)

        agent_1 = create(:user, account: account, role: :agent)
        create(:inbox_member, user: agent_1, inbox: attended_conversation.inbox)
        create(:inbox_member, user: agent_1, inbox: unattended_conversation_no_first_reply.inbox)
        create(:inbox_member, user: agent_1, inbox: unattended_conversation_waiting_since.inbox)

        get "/api/v1/accounts/#{account.id}/conversations",
            headers: agent_1.create_new_auth_token,
            params: { conversation_type: 'unattended' },
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:data][:meta][:all_count]).to eq(2)
        expect(body[:data][:payload].count).to eq(2)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/meta' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/meta"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation = create(:conversation, account: account)
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns all conversations counts' do
        get "/api/v1/accounts/#{account.id}/conversations/meta",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:meta].keys).to include(:all_count, :mine_count, :assigned_count, :unassigned_count)
        expect(body[:meta][:all_count]).to eq(1)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/unread_counts' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/unread_counts"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:visible_inbox) { create(:inbox, account: account) }
      let(:hidden_inbox) { create(:inbox, account: account) }
      let(:label) { create(:label, account: account, title: 'billing', show_on_sidebar: true) }
      let(:team) { create(:team, account: account, allow_auto_assign: false) }

      before do
        create(:inbox_member, user: agent, inbox: visible_inbox)
        create(:team_member, user: agent, team: team)
      end

      after do
        Conversations::UnreadCounts::Store.clear_account!(account.id)
      end

      context 'when conversation unread counts feature is enabled' do
        before do
          account.enable_features!(:conversation_unread_counts)
        end

        it 'returns unread conversation counts scoped to the signed-in user' do
          create_unread_conversation(account: account, inbox: visible_inbox, labels: [label.title])
          create_unread_conversation(account: account, inbox: hidden_inbox, labels: [label.title])

          get "/api/v1/accounts/#{account.id}/conversations/unread_counts",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['payload']).to eq(
            'all_count' => 1,
            'inboxes' => { visible_inbox.id.to_s => 1 },
            'labels' => { label.id.to_s => 1 },
            'teams' => {}
          )
        end

        it 'returns unread team conversation counts scoped to the signed-in user' do
          create_unread_conversation(account: account, inbox: visible_inbox, team: team)
          create_unread_conversation(account: account, inbox: hidden_inbox, team: team)

          get "/api/v1/accounts/#{account.id}/conversations/unread_counts",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['payload']['teams']).to eq(team.id.to_s => 1)
        end

        it 'returns filtered unread counts when the filtered count feature is enabled' do
          account.enable_features!(:unread_count_for_filters)
          allow(Conversations::UnreadCounts::FilteredCountInstrumentation).to receive(:summarize_request) do |**_attributes, &block|
            block.call
          end
          mentioned = create_unread_conversation(account: account, inbox: visible_inbox)
          create(:mention, account: account, conversation: mentioned, user: agent)

          get "/api/v1/accounts/#{account.id}/conversations/unread_counts",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['payload']).to include(
            'mentions_count' => 1,
            'participating_count' => 0,
            'unattended_count' => 1,
            'folders' => {}
          )
          expect(Conversations::UnreadCounts::FilteredCountInstrumentation).to have_received(:summarize_request).with(account_id: account.id)
        end
      end

      it 'returns forbidden when conversation unread counts feature is disabled' do
        get "/api/v1/accounts/#{account.id}/conversations/unread_counts",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('Conversation unread counts feature not enabled for this account')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/search' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/search", params: { q: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation = create(:conversation, account: account)
        create(:message, conversation: conversation, account: account, content: 'test1')
        create(:message, conversation: conversation, account: account, content: 'test2')
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns all conversations with messages containing the search query' do
        get "/api/v1/accounts/#{account.id}/conversations/search",
            headers: agent.create_new_auth_token,
            params: { q: 'test1' },
            as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data[:meta][:all_count]).to eq(1)
        expect(response_data[:payload].first[:messages].first[:content]).to eq 'test1'
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/filter' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/filter", params: { q: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation = create(:conversation, account: account)
        create(:message, conversation: conversation, account: account, content: 'test1')
        create(:message, conversation: conversation, account: account, content: 'test2')
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns all conversations matching the query' do
        post "/api/v1/accounts/#{account.id}/conversations/filter",
             headers: agent.create_new_auth_token,
             params: {
               payload: [{
                 attribute_key: 'status',
                 filter_operator: 'equal_to',
                 values: ['open']
               }]
             },
             as: :json

        expect(response).to have_http_status(:success)
        expect(response).to conform_schema(200)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data.count).to eq(2)
      end

      it 'returns error if the filters contain invalid attributes' do
        post "/api/v1/accounts/#{account.id}/conversations/filter",
             headers: agent.create_new_auth_token,
             params: {
               payload: [{
                 attribute_key: 'phone_number',
                 filter_operator: 'equal_to',
                 values: ['open']
               }]
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data[:error]).to include('Invalid attribute key - [phone_number]')
      end

      it 'returns error if the filters contain invalid operator' do
        post "/api/v1/accounts/#{account.id}/conversations/filter",
             headers: agent.create_new_auth_token,
             params: {
               payload: [{
                 attribute_key: 'status',
                 filter_operator: 'eq',
                 values: ['open']
               }]
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data[:error]).to eq('Invalid operator. The allowed operators for status are [equal_to,not_equal_to].')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/:id' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'does not shows the conversation if you do not have access to it' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'shows the conversation if you are an administrator' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response).to conform_schema(200)
        expect(JSON.parse(response.body, symbolize_names: true)[:id]).to eq(conversation.display_id)
      end

      it 'shows the conversation if you are an agent with access to inbox' do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body, symbolize_names: true)[:id]).to eq(conversation.display_id)
      end

      # A Mesa do ticket vinculado - pra lista de conversas poder dizer, ao
      # lado de quem atende, se aquele assunto e' de uma Mesa ou de outra.
      it 'carries the Mesa name of a ticket linked to the conversation' do
        team = create(:team, account: account, name: 'Suporte N2')
        column = create(:ticket_column, team: team)
        ticket = create(:ticket, account: account, team: team, ticket_column: column)
        ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response.parsed_body['ticket_team_name']).to eq(team.reload.name)
      end

      it 'carries no Mesa name when there is no linked ticket' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response.parsed_body['ticket_team_name']).to be_nil
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/conversations/:id' do
    let(:conversation) { create(:conversation, account: account) }
    let(:params) { { priority: 'high' } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
              params: params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'does not update the conversation if you do not have access to it' do
        patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
              params: params,
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'updates the conversation if you are an administrator' do
        patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
              params: params,
              headers: administrator.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(response).to conform_schema(200)
        expect(JSON.parse(response.body, symbolize_names: true)[:priority]).to eq('high')
      end

      it 'updates the conversation if you are an agent with access to inbox' do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
        patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
              params: params,
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body, symbolize_names: true)[:priority]).to eq('high')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations' do
    let(:contact) { create(:contact, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations",
             params: { source_id: contact_inbox.source_id },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent, auto_offline: false) }
      let(:team) { create(:team, account: account) }

      it 'will not create a new conversation if agent does not have access to inbox' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        additional_attributes = { test: 'test' }
        post "/api/v1/accounts/#{account.id}/conversations",
             headers: agent.create_new_auth_token,
             params: { source_id: contact_inbox.source_id, additional_attributes: additional_attributes },
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      context 'when it is an authenticated user who has access to the inbox' do
        before do
          create(:inbox_member, user: agent, inbox: inbox)
          create(:team_member, user: agent, team: team)
        end

        it 'creates a new conversation' do
          allow(Rails.configuration.dispatcher).to receive(:dispatch)
          additional_attributes = { test: 'test' }
          post "/api/v1/accounts/#{account.id}/conversations",
               headers: agent.create_new_auth_token,
               params: { source_id: contact_inbox.source_id, additional_attributes: additional_attributes },
               as: :json

          expect(response).to have_http_status(:success)
          expect(response).to conform_schema(200)
          response_data = JSON.parse(response.body, symbolize_names: true)
          expect(response_data[:additional_attributes]).to eq(additional_attributes)
        end

        it 'does not create a new conversation if source_id is not unique' do
          new_contact = create(:contact, account: account)

          post "/api/v1/accounts/#{account.id}/conversations",
               headers: agent.create_new_auth_token,
               params: { source_id: contact_inbox.source_id, inbox_id: inbox.id, contact_id: new_contact.id },
               as: :json
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'creates a conversation in specificed status' do
          allow(Rails.configuration.dispatcher).to receive(:dispatch)
          post "/api/v1/accounts/#{account.id}/conversations",
               headers: agent.create_new_auth_token,
               params: { source_id: contact_inbox.source_id, status: 'pending' },
               as: :json

          expect(response).to have_http_status(:success)
          response_data = JSON.parse(response.body, symbolize_names: true)
          expect(response_data[:status]).to eq('pending')
        end

        it 'creates a new conversation with message when message is passed' do
          allow(Rails.configuration.dispatcher).to receive(:dispatch)
          post "/api/v1/accounts/#{account.id}/conversations",
               headers: agent.create_new_auth_token,
               params: { source_id: contact_inbox.source_id, message: { content: 'hi' } },
               as: :json

          expect(response).to have_http_status(:success)
          response_data = JSON.parse(response.body, symbolize_names: true)
          expect(response_data[:additional_attributes]).to eq({})
          expect(account.conversations.find_by(display_id: response_data[:id]).messages.outgoing.first.content).to eq 'hi'
        end

        # "Abrir conversa" na aba Comunicacao de um ticket: a conversa nasce JA vinculada a ele,
        # na mesma criacao.
        context 'when it is opened from a ticket (ticket_id)' do
          let(:column) { create(:ticket_column, team: team) }
          let(:ticket) { create(:ticket, account: account, team: team, ticket_column: column) }

          def open_from(target_ticket)
            allow(Rails.configuration.dispatcher).to receive(:dispatch)
            post "/api/v1/accounts/#{account.id}/conversations",
                 headers: agent.create_new_auth_token,
                 params: { source_id: contact_inbox.source_id, message: { content: 'oi' }, ticket_id: target_ticket.id },
                 as: :json
          end

          it 'links the new conversation to the ticket' do
            open_from(ticket)

            expect(response).to have_http_status(:success)
            conversation = account.conversations.find_by(display_id: response.parsed_body['id'])
            expect(ticket.reload.conversations).to include(conversation)
            expect(ticket.ticket_activities.where(activity_type: :conversation_linked)).to exist
          end

          it 'does not link anything when no ticket is given' do
            allow(Rails.configuration.dispatcher).to receive(:dispatch)
            post "/api/v1/accounts/#{account.id}/conversations",
                 headers: agent.create_new_auth_token,
                 params: { source_id: contact_inbox.source_id },
                 as: :json

            expect(response).to have_http_status(:success)
            expect(TicketConversation.count).to eq(0)
          end

          it '404s for a ticket of another account, creating no conversation' do
            outro = create(:account)
            alheio = create(:ticket, account: outro, ticket_column: create(:ticket_column, team: create(:team, account: outro)))

            expect { open_from(alheio) }.not_to(change { account.conversations.count })

            expect(response).to have_http_status(:not_found)
          end

          it 'refuses an agent who cannot change the ticket, creating no conversation' do
            outra_mesa = create(:team, account: account)
            do_outro = create(:ticket, account: account, team: outra_mesa, ticket_column: create(:ticket_column, team: outra_mesa))

            expect { open_from(do_outro) }.not_to(change { account.conversations.count })

            expect(response).to have_http_status(:unauthorized)
          end
        end

        it 'calls contact inbox builder if contact_id and inbox_id is present' do
          builder = double
          allow(Rails.configuration.dispatcher).to receive(:dispatch)
          allow(ContactInboxBuilder).to receive(:new).with(contact: contact, inbox: inbox, source_id: nil, hmac_verified: false).and_return(builder)
          allow(builder).to receive(:perform)
          expect(builder).to receive(:perform)

          post "/api/v1/accounts/#{account.id}/conversations",
               headers: agent.create_new_auth_token,
               params: { contact_id: contact.id, inbox_id: inbox.id, hmac_verified: 'false' },
               as: :json
        end

        it 'creates a new conversation with assignee and team' do
          allow(Rails.configuration.dispatcher).to receive(:dispatch)
          post "/api/v1/accounts/#{account.id}/conversations",
               headers: agent.create_new_auth_token,
               params: { source_id: contact_inbox.source_id, contact_id: contact.id, inbox_id: inbox.id, assignee_id: agent.id, team_id: team.id },
               as: :json

          expect(response).to have_http_status(:success)
          response_data = JSON.parse(response.body, symbolize_names: true)
          expect(response_data[:meta][:assignee][:name]).to eq(agent.name)
          expect(response_data[:meta][:team][:name]).to eq(team.name)
        end
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/toggle_status' do
    let(:conversation) { create(:conversation, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:pending_conversation) { create(:conversation, inbox: inbox, account: account, status: 'pending') }
    let(:agent_bot) { create(:agent_bot, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'toggles the conversation status if status is empty' do
        expect(conversation.status).to eq('open')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: '' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('resolved')
      end

      # "Cancelar conversa" exige motivo e cancela, junto, os tickets em andamento
      # ligados a ela - com o mesmo motivo. Ticket ja finalizado nao e' tocado.
      describe 'cancelling the conversation' do
        let(:team) { create(:team, account: account) }
        let(:column) { create(:ticket_column, team: team) }
        let(:open_ticket) { create(:ticket, account: account, team: team, ticket_column: column) }
        let(:closed_ticket) do
          create(:ticket, account: account, team: team, ticket_column: column).tap do |t|
            t.update_columns(status: Ticket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        def cancel_conversation(params = {})
          post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
               headers: agent.create_new_auth_token,
               params: { status: 'resolved', cancelled: true }.merge(params),
               as: :json
        end

        before do
          [open_ticket, closed_ticket].each do |ticket|
            ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)
          end
        end

        it 'refuses to cancel without a reason, leaving conversation and tickets untouched' do
          cancel_conversation

          expect(response).to have_http_status(:unprocessable_entity)
          expect(conversation.reload.status).to eq('open')
          expect(open_ticket.reload.status).to eq('open')
        end

        it 'cancels the conversation and the open linked ticket with the same reason' do
          cancel_conversation(cancel_reason: 'Cliente desistiu')

          expect(response).to have_http_status(:success)
          expect(conversation.reload.status).to eq('resolved')
          expect(conversation.additional_attributes['cancelled_reason']).to eq('Cliente desistiu')
          expect(open_ticket.reload.status).to eq('cancelled')
          expect(open_ticket.close_reason).to eq('Cliente desistiu')
        end

        it 'does not touch a ticket that is already closed' do
          cancel_conversation(cancel_reason: 'Cliente desistiu')

          expect(closed_ticket.reload.status).to eq('closed')
        end

        # Ticket com mais de uma conversa: a conversa pode ser so' um dos assuntos
        # dele, entao cancelar a conversa NAO o cancela - so' se quem cancelou
        # escolheu isso.
        context 'when the ticket has other conversations too' do
          let(:other_conversation) { create(:conversation, account: account) }
          let(:shared_ticket) { create(:ticket, account: account, team: team, ticket_column: column) }

          before do
            [conversation, other_conversation].each do |c|
              shared_ticket.ticket_conversations.create!(account_id: account.id, conversation: c)
            end
          end

          it 'lists the other conversations count so the agent can be asked' do
            get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/linked_tickets",
                headers: agent.create_new_auth_token,
                as: :json

            payload = response.parsed_body['payload'].index_by { |t| t['id'] }
            expect(payload[shared_ticket.id]['other_conversations_count']).to eq(1)
            expect(payload[open_ticket.id]['other_conversations_count']).to eq(0)
            expect(payload.keys).not_to include(closed_ticket.id)
          end

          it 'cancels only the conversation by default, keeping the shared ticket open' do
            cancel_conversation(cancel_reason: 'Cliente desistiu')

            expect(conversation.reload.status).to eq('resolved')
            expect(shared_ticket.reload.status).to eq('open')
            # o ticket so' desta conversa continua sendo cancelado junto
            expect(open_ticket.reload.status).to eq('cancelled')
          end

          it 'cancels the shared ticket too when it was chosen' do
            cancel_conversation(cancel_reason: 'Cliente desistiu', cancel_ticket_ids: [shared_ticket.id])

            expect(shared_ticket.reload.status).to eq('cancelled')
            expect(shared_ticket.close_reason).to eq('Cliente desistiu')
          end

          it 'ignores ids of tickets that are not linked to the conversation' do
            unrelated = create(:ticket, account: account, team: team, ticket_column: column)

            cancel_conversation(cancel_reason: 'Cliente desistiu', cancel_ticket_ids: [unrelated.id])

            expect(unrelated.reload.status).to eq('open')
          end
        end
      end

      it 'toggles the conversation status to open from pending' do
        conversation.update!(status: 'pending')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: 'open' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(response).to conform_schema(200)
        expect(conversation.reload.status).to eq('open')
      end

      it 'self assign if agent changes the conversation status to open' do
        conversation.update!(status: 'pending')
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             as: :json
        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('open')
        expect(conversation.reload.assignee_id).to eq(agent.id)
      end

      it 'does not self assign and clears the agent bot owner if admin changes the conversation status to open' do
        conversation.update!(status: 'pending', assignee: nil, assignee_agent_bot: agent_bot)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('open')
        expect(conversation.reload.assignee_id).not_to eq(administrator.id)
        expect(conversation.reload.assignee_agent_bot).to be_nil
      end

      it 'toggles the conversation status to specific status when parameter is passed' do
        expect(conversation.status).to eq('open')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: 'pending' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('pending')
      end

      it 'toggles the conversation status to snoozed when parameter is passed' do
        expect(conversation.status).to eq('open')
        snoozed_until = (DateTime.now.utc + 2.days).to_i
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: 'snoozed', snoozed_until: snoozed_until },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('snoozed')
        expect(conversation.reload.snoozed_until.to_i).to eq(snoozed_until)
      end
    end

    context 'when it is an authenticated bot' do
      # this test will basically ensure that the status actually changes
      # regardless of the value to be done
      it 'returns authorized for arbritrary status' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)

        conversation.update!(status: 'open')
        expect(conversation.reload.status).to eq('open')
        snoozed_until = (DateTime.now.utc + 2.days).to_i

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { status: 'snoozed', snoozed_until: snoozed_until },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('snoozed')
      end

      it 'triggers handoff event when moving from pending to open' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        post "/api/v1/accounts/#{account.id}/conversations/#{pending_conversation.display_id}/toggle_status",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { status: 'open' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(pending_conversation.reload.status).to eq('open')
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Events::Types::CONVERSATION_BOT_HANDOFF, kind_of(Time), conversation: pending_conversation, notifiable_assignee_change: false,
                                                                        changed_attributes: anything, performed_by: anything)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/toggle_priority' do
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account) }
    let(:pending_conversation) { create(:conversation, inbox: inbox, account: account, status: 'pending') }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:agent_bot) { create(:agent_bot, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'toggles the conversation priority to nil if no value is passed' do
        expect(conversation.priority).to be_nil

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority",
             headers: agent.create_new_auth_token,
             params: { priority: 'low' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.priority).to eq('low')
      end

      it 'toggles the conversation priority' do
        conversation.priority = 'low'
        conversation.save!
        expect(conversation.reload.priority).to eq('low')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.priority).to be_nil
      end
    end

    context 'when it is an authenticated bot' do
      it 'toggle the priority of the bot agent conversation' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)

        conversation.update!(priority: 'low')
        expect(conversation.reload.priority).to eq('low')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { priority: 'high' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.priority).to eq('high')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/toggle_typing_status' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'toggles the conversation status' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: agent.create_new_auth_token,
             params: { typing_status: 'on', is_private: false },
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Conversation::CONVERSATION_TYPING_ON, kind_of(Time), { conversation: conversation, user: agent, is_private: false })
      end

      it 'toggles the conversation status for private notes' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: agent.create_new_auth_token,
             params: { typing_status: 'on', is_private: true },
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Conversation::CONVERSATION_TYPING_ON, kind_of(Time), { conversation: conversation, user: agent, is_private: true })
      end
    end

    context 'when it is an authenticated bot' do
      let(:agent_bot) { create(:agent_bot, account: account) }

      it 'toggles the conversation typing status' do
        create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: agent_bot)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { typing_status: 'on', is_private: false },
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Conversation::CONVERSATION_TYPING_ON, kind_of(Time), { conversation: conversation, user: agent_bot, is_private: false })
      end
    end

    context 'when it is an authenticated platform app token' do
      let(:platform_app) { create(:platform_app) }

      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: { api_access_token: platform_app.access_token.token },
             params: { typing_status: 'on', is_private: false },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/update_last_seen' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'updates last seen' do
        conversation.update!(agent_last_seen_at: nil)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.agent_last_seen_at).not_to be_nil
      end

      it 'updates assignee last seen' do
        conversation.update!(assignee_id: agent.id, agent_last_seen_at: nil)

        expect(conversation.reload.assignee_last_seen_at).to be_nil

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.assignee_last_seen_at).not_to be_nil
      end

      it 'marks unread notifications as read when updating last seen' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        notification = create(:notification, account: account, user: agent, primary_actor: conversation, read_at: nil)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(notification.reload.read_at).to be_present
        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'notification.updated',
          kind_of(Time),
          hash_including(notification: have_attributes(id: notification.id))
        )
      end

      it 'throttles updates within an hour when there are no unread messages' do
        conversation.update!(agent_last_seen_at: 30.minutes.ago)
        # Ensure all messages are older than agent_last_seen_at (no unread messages)
        # rubocop:disable Rails/SkipsModelValidations
        conversation.messages.update_all(created_at: 1.hour.ago)
        # rubocop:enable Rails/SkipsModelValidations
        initial_last_seen = conversation.agent_last_seen_at

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.agent_last_seen_at).to be_within(1.second).of(initial_last_seen)
      end

      it 'updates even within an hour when there are unread messages' do
        conversation.update!(agent_last_seen_at: 30.minutes.ago)
        # Create a new message after agent_last_seen_at (unread message)
        create(:message, conversation: conversation, created_at: 5.minutes.ago)
        initial_last_seen = conversation.agent_last_seen_at

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.agent_last_seen_at).not_to be_within(1.second).of(initial_last_seen)
        expect(conversation.reload.agent_last_seen_at).to be > initial_last_seen
      end

      it 'refreshes unread count cache when conversation is marked read' do
        account.enable_features!(:conversation_unread_counts)
        conversation.update!(agent_last_seen_at: 1.hour.ago)
        create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :incoming, created_at: 5.minutes.ago)
        Conversations::UnreadCounts::Builder.new(account).build_base!

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        inbox_key = Conversations::UnreadCounts::Store.inbox_key(account.id, conversation.inbox_id)
        expect(response).to have_http_status(:success)
        expect(Conversations::UnreadCounts::Store.counts_for_keys([inbox_key])).to eq(inbox_key => 0)
      ensure
        Conversations::UnreadCounts::Store.clear_account!(account.id)
      end

      it 'refreshes unread count cache before invalidating filtered counts when conversation is marked read' do
        account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
        conversation.update!(agent_last_seen_at: 1.hour.ago)
        create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :incoming, created_at: 5.minutes.ago)
        notifier = instance_double(Conversations::UnreadCounts::Notifier)
        invalidator = instance_double(Conversations::UnreadCounts::FilteredCountInvalidator)

        allow(Conversations::UnreadCounts::Notifier).to receive(:new).with(conversation).and_return(notifier)
        allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).with(account).and_return(invalidator)
        expect(notifier).to receive(:perform).ordered.and_return(true)
        expect(invalidator).to receive(:conversation_changed!).ordered.and_return(true)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
      end

      it 'invalidates filtered unread counts when conversation is marked read' do
        conversation.update!(agent_last_seen_at: 1.hour.ago)
        create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :incoming, created_at: 5.minutes.ago)
        account.enable_features!(:unread_count_for_filters)

        expect do
          post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
               headers: agent.create_new_auth_token,
               as: :json
        end.to change { Conversations::UnreadCounts::FilteredCountStore.conversation_version(account.id) }.by(1)
        expect(response).to have_http_status(:success)
      end

      it 'notifies clients when marking read only affects filtered counts' do
        account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
        conversation.update!(agent_last_seen_at: 1.hour.ago)
        create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :incoming, created_at: 5.minutes.ago)
        allow(Conversations::UnreadCounts::Refresher).to receive(:new).and_return(
          instance_double(Conversations::UnreadCounts::Refresher, perform: false)
        )
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'conversation.unread_count_changed',
          kind_of(Time),
          conversation: conversation
        )
      end

      it 'updates both if one timestamp is old even when the other is recent' do
        conversation.update!(assignee_id: agent.id, agent_last_seen_at: 2.hours.ago, assignee_last_seen_at: 30.minutes.ago)
        # Ensure all messages are older than assignee_last_seen_at (no unread messages)
        # rubocop:disable Rails/SkipsModelValidations
        conversation.messages.update_all(created_at: 1.hour.ago)
        # rubocop:enable Rails/SkipsModelValidations

        initial_agent_last_seen = conversation.agent_last_seen_at

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        # Both should be updated because agent_last_seen_at is old
        expect(conversation.reload.agent_last_seen_at).to be > initial_agent_last_seen
        expect(conversation.reload.assignee_last_seen_at).to be > initial_agent_last_seen
      end

      it 'throttles only when both timestamps are recent and no unread messages' do
        conversation.update!(assignee_id: agent.id, agent_last_seen_at: 30.minutes.ago, assignee_last_seen_at: 30.minutes.ago)
        # Ensure all messages are older (no unread messages)
        # rubocop:disable Rails/SkipsModelValidations
        conversation.messages.update_all(created_at: 1.hour.ago)
        # rubocop:enable Rails/SkipsModelValidations

        initial_agent_last_seen = conversation.agent_last_seen_at
        initial_assignee_last_seen = conversation.assignee_last_seen_at

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        # Both should remain unchanged (throttled)
        expect(conversation.reload.agent_last_seen_at).to be_within(1.second).of(initial_agent_last_seen)
        expect(conversation.reload.assignee_last_seen_at).to be_within(1.second).of(initial_assignee_last_seen)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/unread' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
        create(:message, conversation: conversation, account: account, inbox: conversation.inbox, content: 'Hello', message_type: 'incoming')
      end

      it 'updates last seen' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        last_seen_at = conversation.messages.incoming.last.created_at - 1.second
        expect(conversation.reload.agent_last_seen_at).to eq(last_seen_at)
        expect(conversation.reload.assignee_last_seen_at).to eq(last_seen_at)
      end

      it 'refreshes unread count cache when conversation is marked unread' do
        account.enable_features!(:conversation_unread_counts)
        conversation.update!(agent_last_seen_at: 1.minute.from_now, assignee_last_seen_at: 1.minute.from_now)
        Conversations::UnreadCounts::Builder.new(account).build_base!

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread",
             headers: agent.create_new_auth_token,
             as: :json

        inbox_key = Conversations::UnreadCounts::Store.inbox_key(account.id, conversation.inbox_id)
        expect(response).to have_http_status(:success)
        expect(Conversations::UnreadCounts::Store.counts_for_keys([inbox_key])).to eq(inbox_key => 1)
      ensure
        Conversations::UnreadCounts::Store.clear_account!(account.id)
      end

      it 'refreshes unread count cache before invalidating filtered counts when conversation is marked unread' do
        account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
        conversation.update!(agent_last_seen_at: 1.minute.from_now, assignee_last_seen_at: 1.minute.from_now)
        notifier = instance_double(Conversations::UnreadCounts::Notifier)
        invalidator = instance_double(Conversations::UnreadCounts::FilteredCountInvalidator)

        allow(Conversations::UnreadCounts::Notifier).to receive(:new).with(conversation).and_return(notifier)
        allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).with(account).and_return(invalidator)
        expect(notifier).to receive(:perform).ordered.and_return(true)
        expect(invalidator).to receive(:conversation_changed!).ordered.and_return(true)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
      end

      it 'invalidates filtered unread counts when conversation is marked unread' do
        conversation.update!(agent_last_seen_at: 1.minute.from_now, assignee_last_seen_at: 1.minute.from_now)
        account.enable_features!(:unread_count_for_filters)

        expect do
          post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread",
               headers: agent.create_new_auth_token,
               as: :json
        end.to change { Conversations::UnreadCounts::FilteredCountStore.conversation_version(account.id) }.by(1)
        expect(response).to have_http_status(:success)
      end

      it 'notifies clients when marking unread only affects filtered counts' do
        account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
        conversation.update!(agent_last_seen_at: 1.minute.from_now, assignee_last_seen_at: 1.minute.from_now)
        allow(Conversations::UnreadCounts::Refresher).to receive(:new).and_return(
          instance_double(Conversations::UnreadCounts::Refresher, perform: false)
        )
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
          'conversation.unread_count_changed',
          kind_of(Time),
          conversation: conversation
        )
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/mute' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/mute"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'mutes conversation' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/mute",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.resolved?).to be(true)
        expect(conversation.reload.muted?).to be(true)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/unmute' do
    let(:conversation) { create(:conversation, account: account).tap(&:mute!) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unmute"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'unmutes conversation' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unmute",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.muted?).to be(false)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/transcript' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/transcript"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:params) { { email: 'test@test.com' } }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'mutes conversation' do
        mailer = double
        allow(ConversationReplyMailer).to receive(:with).and_return(mailer)
        allow(mailer).to receive(:conversation_transcript)
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/transcript",
             headers: agent.create_new_auth_token,
             params: params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(mailer).to have_received(:conversation_transcript).with(conversation, 'test@test.com')
      end

      it 'renders error when parameter missing' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/transcript",
             headers: agent.create_new_auth_token,
             params: {},
             as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/custom_attributes' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:custom_attributes) { { user_id: 1001, created_date: '23/12/2012', subscription_id: 12 } }
      let(:valid_params) { { custom_attributes: custom_attributes } }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'updates custom attributes' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
             headers: agent.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_attributes).not_to be_nil
        expect(conversation.reload.custom_attributes.count).to eq 3
      end

      it 'merges custom attributes when merge is enabled' do
        conversation.update!(custom_attributes: { existing_key: 'keep', user_id: 1 })

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
             headers: agent.create_new_auth_token,
             params: { custom_attributes: { user_id: 1001 }, merge: true },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_attributes).to eq({ 'existing_key' => 'keep', 'user_id' => 1001 })
      end

      it 'replaces custom attributes by default' do
        conversation.update!(custom_attributes: { existing_key: 'gone' })

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
             headers: agent.create_new_auth_token,
             params: { custom_attributes: { user_id: 1001 } },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_attributes).to eq({ 'user_id' => 1001 })
      end
    end

    context 'when it is a bot' do
      let(:agent_bot) { create(:agent_bot, account: account) }
      let(:custom_attributes) { { bot_id: 1001, flow_name: 'support_flow', step: 'greeting' } }
      let(:valid_params) { { custom_attributes: custom_attributes } }

      before do
        create(:agent_bot_inbox, agent_bot: agent_bot, inbox: conversation.inbox)
      end

      it 'updates custom attributes' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
             headers: { api_access_token: agent_bot.access_token.token },
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_attributes).not_to be_nil
        expect(conversation.reload.custom_attributes.count).to eq 3
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/destroy_custom_attributes' do
    let(:conversation) { create(:conversation, account: account, custom_attributes: { test: 'test', test1: 'test1' }) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/destroy_custom_attributes"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'deletes the given custom attribute' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/destroy_custom_attributes",
             headers: agent.create_new_auth_token,
             params: { custom_attributes: ['test'] },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(conversation.reload.custom_attributes).to eq({ 'test1' => 'test1' })
        expect(response.parsed_body['custom_attributes']).to eq({ 'test1' => 'test1' })
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/:id/attachments' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      before do
        create(:message, :with_attachment, conversation: conversation, account: account, inbox: conversation.inbox, message_type: 'incoming')
      end

      it 'does not return the attachments if you do not have access to it' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'return the attachments if you are an administrator' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_body = response.parsed_body
        attachment = conversation.messages.last.attachments.first
        expect(response_body['payload'].first['id']).to eq(attachment.id)
        expect(response_body['payload'].first['file_type']).to eq('image')
        expect(response_body['payload'].first['sender']['id']).to eq(conversation.messages.last.sender.id)
      end

      it 'return the attachments if you are an agent with access to inbox' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_body = response.parsed_body
        expect(response_body['payload'].length).to eq(1)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/conversations/:id' do
    let(:conversation) { create(:conversation, account: account) }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:administrator) { create(:user, account: account, role: :administrator) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
        response_body = response.parsed_body
        expect(response_body['error']).to eq('You are not authorized to do this action')
      end
    end

    context 'when it is an authenticated administrator' do
      before do
        create(:inbox_member, user: administrator, inbox: conversation.inbox)
      end

      it 'successfully deletes the conversation' do
        expect do
          delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
                 headers: administrator.create_new_auth_token,
                 as: :json
        end.to have_enqueued_job(DeleteObjectJob).with(conversation, administrator, anything)

        expect(response).to have_http_status(:ok)
      end

      it 'can delete conversations from inboxes without direct access' do
        other_inbox = create(:inbox, account: account)
        other_conversation = create(:conversation, account: account, inbox: other_inbox)

        expect do
          delete "/api/v1/accounts/#{account.id}/conversations/#{other_conversation.display_id}",
                 headers: administrator.create_new_auth_token,
                 as: :json
        end.to have_enqueued_job(DeleteObjectJob).with(other_conversation, administrator, anything)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
