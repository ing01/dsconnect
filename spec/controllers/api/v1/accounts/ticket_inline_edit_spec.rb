require 'rails_helper'

# Each value on the detail page is edited where it appears, through the ticket's
# existing `update` endpoint - there is no generic ticket form.
RSpec.describe 'Ticket inline editing', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team) }

  def update_ticket(attributes, user: administrator)
    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
          params: { ticket: attributes }, headers: user.create_new_auth_token, as: :json
  end

  describe 'title' do
    it 'saves the new title' do
      update_ticket({ title: 'Relacao de produtos' })

      expect(response).to have_http_status(:success)
      expect(ticket.reload.title).to eq('Relacao de produtos')
    end

    it 'refuses an empty title' do
      update_ticket({ title: '' })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.title).to be_present
    end

    # The number identifies the ticket and is not part of the form.
    it 'never changes the ticket number' do
      expect { update_ticket({ title: 'outro' }) }.not_to(change { ticket.reload.display_id })
    end

    it 'records the change in the history' do
      previous = ticket.title

      update_ticket({ title: 'Relacao de produtos' })

      activity = ticket.ticket_activities.find_by(activity_type: :title_changed)
      expect(activity.previous_value).to eq(previous)
      expect(activity.new_value).to eq('Relacao de produtos')
      expect(activity.user).to eq(administrator)
    end
  end

  describe 'company' do
    let(:company) { create(:company, account: account) }
    let(:other_company) { create(:company, account: account) }

    it 'points the ticket at the chosen Empresa' do
      update_ticket({ company_id: company.id })

      expect(ticket.reload.company).to eq(company)
    end

    # The ticket references the Company record; nothing is copied as loose text.
    it 'stores no duplicated company name' do
      company # created up front, so the count is measured around the update alone

      expect { update_ticket({ company_id: company.id }) }.not_to change(Company, :count)

      expect(ticket.reload.attributes).not_to have_key('company_name')
    end

    it 'replaces an existing Empresa' do
      ticket.update!(company: company)

      update_ticket({ company_id: other_company.id })

      expect(ticket.reload.company).to eq(other_company)
    end

    it 'clears it when none is chosen' do
      ticket.update!(company: company)

      update_ticket({ company_id: nil })

      expect(ticket.reload.company).to be_nil
    end

    it 'refuses an Empresa from another account' do
      foreign = create(:company, account: create(:account))

      update_ticket({ company_id: foreign.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.company).to be_nil
    end

    it 'records Empresa anterior -> Empresa nova' do
      ticket.update!(company: company)

      update_ticket({ company_id: other_company.id })

      activity = ticket.ticket_activities.where(activity_type: :company_changed).last
      expect(activity.previous_value).to eq(company.id.to_s)
      expect(activity.new_value).to eq(other_company.id.to_s)
    end
  end

  describe 'contact' do
    let(:contact) { create(:contact, account: account) }
    let(:other_contact) { create(:contact, account: account) }

    it 'points the ticket at the chosen Solicitante' do
      update_ticket({ contact_id: contact.id })

      expect(ticket.reload.contact).to eq(contact)
    end

    it 'references the same Contact instead of duplicating it' do
      contact # created up front, so the count is measured around the update alone

      expect { update_ticket({ contact_id: contact.id }) }.not_to change(Contact, :count)
    end

    it 'refuses a Contact from another account' do
      foreign = create(:contact, account: create(:account))

      update_ticket({ contact_id: foreign.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.contact).to be_nil
    end

    it 'records the change in the history' do
      ticket.update!(contact: contact)

      update_ticket({ contact_id: other_contact.id })

      activity = ticket.ticket_activities.where(activity_type: :contact_changed).last
      expect(activity.previous_value).to eq(contact.id.to_s)
      expect(activity.new_value).to eq(other_contact.id.to_s)
    end

    describe 'the Solicitante shown' do
      # `requester_contact` used to be derived from the earliest linked
      # Conversation, which is why it could not be changed on its own. The FK
      # now wins, and the old path stays as the fallback.
      it 'prefers the ticket own contact over the conversation one' do
        conversation = create(:conversation, account: account, contact: other_contact)
        ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)
        ticket.update!(contact: contact)

        get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
            headers: administrator.create_new_auth_token, as: :json

        expect(response.parsed_body['contact']['id']).to eq(contact.id)
      end

      it 'falls back to the conversation contact when the ticket has none' do
        conversation = create(:conversation, account: account, contact: other_contact)
        ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)

        get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
            headers: administrator.create_new_auth_token, as: :json

        expect(response.parsed_body['contact']['id']).to eq(other_contact.id)
      end
    end

    # A ticket opened from a chat already knows its customer, so the FK is
    # populated instead of being left to the fallback.
    it 'is inherited when the ticket is opened from a conversation' do
      contact.update!(company: create(:company, account: account))
      conversation = create(:conversation, account: account, contact: contact)

      post "/api/v1/accounts/#{account.id}/tickets",
           params: { ticket: { title: 'do chat', description: 'detalhes', priority: 'medium',
                               ticket_column_id: column.id,
                               ticket_category_id: team.ticket_categories.first.id },
                     conversation_id: conversation.id },
           headers: administrator.create_new_auth_token, as: :json

      created = Ticket.find(response.parsed_body['id'])
      expect(created.contact).to eq(contact)
      expect(created.company).to eq(contact.company)
    end
  end
end
