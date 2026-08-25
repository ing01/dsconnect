require 'rails_helper'

# The "Acoes do ticket" menu. Each action is a composite operation, so what
# matters here is what survives it, not just that it returns 200.
RSpec.describe 'Ticket actions', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  let(:later_column) { create(:ticket_column, team: team, position: 1) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team) }

  def auth(user = administrator)
    user.create_new_auth_token
  end

  def act(action, ticket_record, params = {}, verb: :patch, user: administrator)
    send(verb, "/api/v1/accounts/#{account.id}/tickets/#{ticket_record.id}/#{action}",
         params: params, headers: auth(user), as: :json)
  end

  describe 'assumir ticket' do
    it 'makes the acting user the assignee' do
      act(:assign_to_me, ticket, {}, user: administrator)

      expect(response).to have_http_status(:success)
      expect(ticket.reload.assignee).to eq(administrator)
    end

    it 'records the previous and the new owner' do
      ticket.update!(assignee: agent)

      act(:assign_to_me, ticket)

      # The setup `update!` logs its own assignee_changed (nil -> agent), so the
      # entry under test is the last one, not the first.
      activity = ticket.ticket_activities.where(activity_type: :assignee_changed).last
      expect(activity.previous_value).to eq(agent.id.to_s)
      expect(activity.new_value).to eq(administrator.id.to_s)
      expect(activity.user).to eq(administrator)
    end

    # TicketPolicy#update? is admin, assignee or Mesa member. A plain agent
    # outside the Mesa must not be able to take the ticket by calling the API
    # directly, whatever the menu shows.
    it 'refuses an agent with no standing in the Mesa' do
      act(:assign_to_me, ticket, {}, user: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(ticket.reload.assignee).to be_nil
    end
  end

  describe 'transferir ticket' do
    let(:other_team) { create(:team, account: account) }
    let(:other_column) { create(:ticket_column, team: other_team) }

    it 'moves Mesa, Estagio, prioridade and responsavel together' do
      other_team.add_members([agent.id])

      act(:transfer, ticket, { ticket: { team_id: other_team.id, ticket_column_id: other_column.id,
                                         status: 'open', priority: 'urgent', assignee_id: agent.id } })

      expect(response).to have_http_status(:success)
      ticket.reload
      expect(ticket.team).to eq(other_team)
      expect(ticket.ticket_column).to eq(other_column)
      expect(ticket.priority).to eq('urgent')
      expect(ticket.assignee).to eq(agent)
    end

    # One operation must read as one event. Without the suppression the four
    # tracked columns would each log their own activity.
    it 'logs a single auditable entry carrying every before/after pair' do
      act(:transfer, ticket, { ticket: { team_id: other_team.id, ticket_column_id: other_column.id,
                                         priority: 'urgent' } })

      transfers = ticket.ticket_activities.where(activity_type: :transferred)
      expect(transfers.count).to eq(1)

      changes = transfers.first.meta['changes']
      expect(changes['priority']).to eq(%w[medium urgent])
      expect(changes['team_id']).to eq([team.id, other_team.id])
      expect(ticket.ticket_activities.where(activity_type: [:team_changed, :priority_changed])).to be_empty
    end

    it 'routes a status change through the model transition, not a bare update' do
      act(:transfer, ticket, { ticket: { ticket_column_id: column.id, status: 'closed' } })

      ticket.reload
      expect(ticket.status).to eq('closed')
      # `closed_at` is written by `close!`; assigning the column directly would
      # leave it nil.
      expect(ticket.closed_at).to be_present
      expect(ticket.ticket_activities.where(activity_type: :closed)).to be_present
    end

    it 'keeps team_id in lockstep with the Estagio it lands in' do
      act(:transfer, ticket, { ticket: { team_id: team.id, ticket_column_id: other_column.id } })

      expect(ticket.reload.team).to eq(other_team)
    end
  end

  # The child goes through the same creation form as everything else, so the
  # form's values are authoritative for every scalar field and `options` only
  # drives the copies the form cannot express.
  describe 'criar ticket filho' do
    let(:contact) { create(:contact, account: account, company: company) }
    let(:company) { create(:company, account: account) }

    before { ticket.update!(company: company) }

    def form_attributes(extra = {})
      { title: 'Ticket filho', description: 'detalhes do filho', priority: 'high',
        team_id: team.id, ticket_column_id: column.id,
        ticket_category_id: team.ticket_categories.first.id }.merge(extra)
    end

    def create_child(options = {}, attributes = form_attributes)
      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/create_child",
           params: { options: options, ticket: attributes }, headers: auth, as: :json
    end

    def child
      Ticket.find(response.parsed_body['id'])
    end

    it 'opens a ticket with its own number, referencing the parent' do
      create_child

      expect(response).to have_http_status(:created)
      expect(child.parent).to eq(ticket)
      expect(child.display_id).not_to eq(ticket.display_id)
    end

    # The agent saw the parent's values pre-filled and may have changed any of
    # them, so what the form submitted wins.
    it 'takes every scalar field from the form, not from the parent' do
      ticket.update!(title: 'titulo do pai', description: 'texto do pai', priority: 'low')

      create_child

      expect(child.title).to eq('Ticket filho')
      expect(child.description).to eq('detalhes do filho')
      expect(child.priority).to eq('high')
    end

    # Duplicating a Company would corrupt the customer base; the child points at
    # the same record.
    it 'references the same Empresa instead of duplicating it' do
      company
      expect { create_child({}, form_attributes(company_id: company.id)) }
        .not_to change(Company, :count)

      expect(child.company_id).to eq(company.id)
    end

    it 'gives the child its own description rather than sharing the parent one' do
      ticket.update!(description: 'texto do pai')
      create_child
      copy = child

      copy.update!(description: 'reescrito')

      expect(ticket.reload.description).to eq('texto do pai')
    end

    it 'lands in the Estagio the form chose' do
      create_child({}, form_attributes(ticket_column_id: later_column.id))

      expect(child.ticket_column).to eq(later_column)
    end

    # The Mesa owns who may be assigned.
    it 'refuses a Responsavel who does not belong to the Mesa' do
      create_child({}, form_attributes(assignee_id: agent.id))

      expect(child.assignee_id).to be_nil
    end

    it 'carries one who does' do
      team.add_members([agent.id])

      create_child({}, form_attributes(assignee_id: agent.id))

      expect(child.assignee).to eq(agent)
    end

    it 'refuses a Categoria from another Mesa' do
      other_team = create(:team, account: account)

      create_child({}, form_attributes(ticket_category_id: other_team.ticket_categories.first.id))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    describe 'the copies the form cannot express' do
      it 'copies followers without duplicating users' do
        ticket.ticket_followers.create!(account_id: account.id, user: agent)
        # `auth` builds the administrator lazily, so both users have to exist
        # before the block for the count to measure the copy alone.
        administrator

        expect { create_child({ followers: true }) }.not_to change(User, :count)

        expect(child.followers).to eq([agent])
      end

      it 'leaves them behind when not ticked' do
        ticket.ticket_followers.create!(account_id: account.id, user: agent)

        create_child

        expect(child.followers).to be_empty
      end

      # Links, never duplicates: `ticket_conversations` is a join table, so no
      # customer message is ever re-inserted.
      it 'links the same conversations instead of copying messages' do
        conversation = create(:conversation, account: account, contact: contact)
        create(:message, account: account, conversation: conversation)
        ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)

        expect { create_child({ conversations: true }) }.not_to change(Message, :count)

        expect(child.conversations).to eq([conversation])
      end

      it 'copies internal comments as new rows attributed to their author' do
        ticket.ticket_comments.create!(account_id: account.id, user: agent, content: 'nota interna')

        create_child({ comments: true })

        expect(child.ticket_comments.pluck(:content, :user_id)).to eq([['nota interna', agent.id]])
      end
    end

    it 'records the relation on both tickets' do
      create_child
      copy = child

      expect(ticket.ticket_activities.where(activity_type: :child_created)).to be_present
      expect(copy.ticket_activities.where(activity_type: :parent_changed)).to be_present
    end
  end

  describe 'referenciar ticket pai' do
    let(:parent) { create(:ticket, account: account, ticket_column: column, team: team) }

    it 'links the ticket to the chosen parent' do
      act(:set_parent, ticket, { parent_id: parent.id })

      expect(response).to have_http_status(:success)
      expect(ticket.reload.parent).to eq(parent)
    end

    # `belongs_to :parent` holds one reference, so a second choice replaces the
    # first rather than accumulating.
    it 'replaces an existing reference' do
      other_parent = create(:ticket, account: account, ticket_column: column, team: team)
      ticket.update!(parent: parent)

      act(:set_parent, ticket, { parent_id: other_parent.id })

      expect(ticket.reload.parent).to eq(other_parent)
    end

    it 'clears the reference when none is sent' do
      ticket.update!(parent: parent)

      act(:set_parent, ticket, { parent_id: nil })

      expect(ticket.reload.parent).to be_nil
    end

    it 'refuses to make a ticket its own parent' do
      act(:set_parent, ticket, { parent_id: ticket.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.parent).to be_nil
    end

    # The cycle guard lives in the model, not the UI - the API accepts a parent
    # directly. A is parent of B, B of C, and C must not become parent of A.
    it 'refuses to close a cycle' do
      b = create(:ticket, account: account, ticket_column: column, team: team, parent: ticket)
      c = create(:ticket, account: account, ticket_column: column, team: team, parent: b)

      act(:set_parent, ticket, { parent_id: c.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.parent).to be_nil
    end

    it 'records the change in the history' do
      act(:set_parent, ticket, { parent_id: parent.id })

      activity = ticket.ticket_activities.find_by(activity_type: :parent_changed)
      expect(activity.new_value).to eq(parent.display_id.to_s)
      expect(activity.user).to eq(administrator)
    end
  end

  describe 'agrupar ticket' do
    let(:source) { create(:ticket, account: account, ticket_column: column, team: team) }

    def merge(source_record = source, user: administrator)
      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/merge",
           params: { source_id: source_record.id }, headers: auth(user), as: :json
    end

    it 'keeps the ticket in view and closes the selected one' do
      merge

      expect(response).to have_http_status(:success)
      expect(ticket.reload.status).to eq('open')
      expect(source.reload.status).to eq('closed')
    end

    # `close_reason` distinguishes this from an ordinary close without needing a
    # global status per reason.
    it 'marks why the merged ticket was closed' do
      merge

      expect(source.reload.close_reason).to eq('merged')
      expect(source.closed_at).to be_present
    end

    it 'creates a real relation in both directions' do
      merge

      expect(source.reload.merged_into).to eq(ticket)
      expect(ticket.reload.merged_tickets).to eq([source])
    end

    # Grouping must preserve access to the original content, not move it.
    it 'moves no content' do
      source.ticket_comments.create!(account_id: account.id, user: agent, content: 'nota')

      merge

      expect(source.reload.ticket_comments.count).to eq(1)
      expect(ticket.reload.ticket_comments).to be_empty
    end

    it 'records the operation on both tickets' do
      merge

      expect(ticket.ticket_activities.find_by(activity_type: :merged_ticket).new_value)
        .to eq(source.display_id.to_s)
      expect(source.ticket_activities.find_by(activity_type: :merged_into).new_value)
        .to eq(ticket.display_id.to_s)
    end

    it 'refuses to group a ticket into itself' do
      merge(ticket)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.merged_into).to be_nil
    end

    it 'refuses to group a ticket that was already grouped' do
      merge
      merge

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'duplicar ticket' do
    before { ticket.update!(description: 'original') }

    it 'creates an independent ticket with a new number' do
      act(:duplicate, ticket, {}, verb: :post)

      expect(response).to have_http_status(:created)
      copy = Ticket.find(response.parsed_body['id'])
      expect(copy.display_id).not_to eq(ticket.display_id)
      expect(copy.description).to eq('original')
    end

    # This is what separates it from "criar ticket filho".
    it 'creates no parent/child relation' do
      act(:duplicate, ticket, {}, verb: :post)

      copy = Ticket.find(response.parsed_body['id'])
      expect(copy.parent_id).to be_nil
      expect(ticket.reload.children).to be_empty
    end

    it 'leaves the original history, comments and lifecycle behind' do
      ticket.ticket_comments.create!(account_id: account.id, user: agent, content: 'nota')
      ticket.close!(administrator)

      act(:duplicate, ticket, {}, verb: :post)

      copy = Ticket.find(response.parsed_body['id'])
      expect(copy.ticket_comments).to be_empty
      expect(copy.status).to eq('open')
      expect(copy.closed_at).to be_nil
    end
  end

  describe 'adicionar horas no SLA' do
    def add_hours(params, user: administrator)
      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/add_sla_hours",
           params: params, headers: auth(user), as: :json
    end

    it 'extends the deadline by the hours given' do
      ticket.update!(due_at: Time.zone.parse('2026-08-25 14:00'))

      add_hours({ hours: 2, reason: 'Cliente pediu prazo' })

      expect(response).to have_http_status(:success)
      expect(ticket.reload.due_at).to eq(Time.zone.parse('2026-08-25 16:00'))
    end

    # "Add 4 hours" on a ticket that was never given a deadline means four hours
    # from now, not a silent no-op.
    it 'counts from now when the ticket had no deadline' do
      add_hours({ hours: 3, reason: 'sem prazo antes' })

      expect(ticket.reload.due_at).to be_within(1.minute).of(3.hours.from_now)
    end

    it 'accepts decimals' do
      ticket.update!(due_at: Time.zone.parse('2026-08-25 14:00'))

      add_hours({ hours: 1.5, reason: 'meia hora a mais' })

      expect(ticket.reload.due_at).to eq(Time.zone.parse('2026-08-25 15:30'))
    end

    it 'persists the extension with its author and both deadlines' do
      previous = Time.zone.parse('2026-08-25 14:00')
      ticket.update!(due_at: previous)

      add_hours({ hours: 2, reason: 'Cliente solicitou prazo adicional' })

      extension = ticket.ticket_sla_extensions.last
      expect(extension.hours).to eq(2)
      expect(extension.reason).to eq('Cliente solicitou prazo adicional')
      expect(extension.user).to eq(administrator)
      expect(extension.previous_due_at).to eq(previous)
      expect(extension.new_due_at).to eq(previous + 2.hours)
    end

    it 'requires a reason' do
      add_hours({ hours: 2, reason: '' })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.due_at).to be_nil
    end

    it 'refuses hours that are zero or negative' do
      add_hours({ hours: 0, reason: 'nada' })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.due_at).to be_nil
    end

    it 'records it in the history with both deadlines' do
      add_hours({ hours: 2, reason: 'motivo' })

      activity = ticket.ticket_activities.find_by(activity_type: :sla_hours_added)
      expect(activity.user).to eq(administrator)
      expect(activity.meta['hours']).to eq(2.0)
      expect(activity.meta['reason']).to eq('motivo')
      expect(activity.new_value).to be_present
    end

    # Stricter than update?: a Mesa member who neither owns the ticket nor
    # administers the account cannot grant more time.
    it 'refuses a Mesa member who does not own the ticket' do
      team.add_members([agent.id])

      add_hours({ hours: 2, reason: 'motivo' }, user: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(ticket.reload.due_at).to be_nil
    end

    it 'allows the assignee' do
      ticket.update!(assignee: agent)

      add_hours({ hours: 2, reason: 'motivo' }, user: agent)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'cancelar ticket' do
    it 'sets the status without deleting anything' do
      ticket # created up front, so the count is measured around the action alone

      expect { act(:cancel, ticket, { reason: 'desistencia' }) }.not_to change(Ticket, :count)

      ticket.reload
      expect(ticket.status).to eq('cancelled')
      expect(ticket.cancelled_at).to be_present
      expect(ticket.close_reason).to eq('desistencia')
    end

    it 'keeps the history, comments and attachments readable' do
      ticket.ticket_comments.create!(account_id: account.id, user: agent, content: 'nota')

      act(:cancel, ticket)

      expect(ticket.reload.ticket_comments.count).to eq(1)
      expect(ticket.ticket_activities).to be_present
    end

    it 'records who cancelled it and when' do
      act(:cancel, ticket, { reason: 'duplicado' })

      activity = ticket.ticket_activities.find_by(activity_type: :cancelled)
      expect(activity.user).to eq(administrator)
      expect(activity.meta['reason']).to eq('duplicado')
    end

    it 'clears the terminal columns on reopen' do
      act(:cancel, ticket)

      act(:reopen, ticket)

      ticket.reload
      expect(ticket.status).to eq('open')
      expect(ticket.cancelled_at).to be_nil
      expect(ticket.close_reason).to be_nil
    end
  end

  describe 'fechar ticket' do
    it 'records the closing date and the acting user' do
      act(:close, ticket)

      ticket.reload
      expect(ticket.status).to eq('closed')
      expect(ticket.closed_at).to be_present
      expect(ticket.ticket_activities.find_by(activity_type: :closed).user).to eq(administrator)
    end
  end

  describe 'conversas relacionadas' do
    let(:contact) { create(:contact, account: account) }

    it 'lists every linked conversation with what the dialog shows' do
      inbox = create(:inbox, account: account)
      two = Array.new(2) do
        conversation = create(:conversation, account: account, contact: contact, inbox: inbox)
        ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)
        conversation
      end

      get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}", headers: auth, as: :json

      payload = response.parsed_body['conversations']
      expect(payload.length).to eq(2)
      expect(payload.map { |c| c['id'] }).to match_array(two.map(&:id))
      expect(payload.first).to include('display_id', 'channel', 'inbox_name', 'contact_name', 'last_activity_at')
    end

    # The dashboard route and the conversations API both resolve on display_id,
    # so the payload has to carry it alongside the primary key.
    it 'carries display_id distinctly from the primary key' do
      conversation = create(:conversation, account: account, contact: contact)
      ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)

      get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}", headers: auth, as: :json

      payload = response.parsed_body['conversations'].first
      expect(payload['id']).to eq(conversation.id)
      expect(payload['display_id']).to eq(conversation.display_id)
    end
  end
end
