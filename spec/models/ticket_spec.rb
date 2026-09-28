require 'rails_helper'

RSpec.describe Ticket do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket_column) }
    it { is_expected.to belong_to(:assignee).optional }
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_many(:ticket_conversations) }
    it { is_expected.to have_many(:conversations) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe 'priority enum' do
    it { is_expected.to define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2, urgent: 3) }
  end

  describe 'default position' do
    it 'assigns the next position within the column when not set' do
      column = create(:ticket_column)
      create(:ticket, ticket_column: column, position: 0)

      ticket = create(:ticket, ticket_column: column)

      expect(ticket.position).to eq(1)
    end
  end

  describe 'linking conversations' do
    it 'links multiple conversations to the same ticket' do
      ticket = create(:ticket)
      conversation_a = create(:conversation, account: ticket.account)
      conversation_b = create(:conversation, account: ticket.account)

      create(:ticket_conversation, ticket: ticket, conversation: conversation_a)
      create(:ticket_conversation, ticket: ticket, conversation: conversation_b)

      expect(ticket.conversations).to contain_exactly(conversation_a, conversation_b)
    end
  end

  describe '#push_event_data' do
    it 'includes the linked conversation ids' do
      ticket = create(:ticket, title: 'Bug no login')
      conversation = create(:conversation, account: ticket.account)
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      expect(ticket.push_event_data[:conversation_ids]).to eq([conversation.id])
    end

    it 'includes display_id and status' do
      ticket = create(:ticket)

      data = ticket.push_event_data
      expect(data[:display_id]).to eq(ticket.display_id)
      expect(data[:status]).to eq('open')
    end

    # O contador da Triagem no menu lateral se serve deste campo para saber se a
    # fila mudou. Sem ele, o numero so ficaria correto ao recarregar a pagina.
    it 'says whether the ticket is waiting in the triage queue' do
      esperando = create(:ticket, pending_triage: true)
      triado = create(:ticket)

      expect(esperando.push_event_data[:pending_triage]).to be(true)
      expect(triado.push_event_data[:pending_triage]).to be(false)
    end
  end

  describe 'status enum' do
    it { is_expected.to define_enum_for(:status).with_values(open: 0, resolved: 1, closed: 2, cancelled: 3) }

    it 'defaults to open' do
      expect(create(:ticket).status).to eq('open')
    end
  end

  describe '#set_display_id' do
    it 'assigns a sequential display_id per account' do
      account = create(:account)
      column = create(:ticket_column, team: create(:team, account: account))

      first = create(:ticket, account: account, ticket_column: column)
      second = create(:ticket, account: account, ticket_column: column)

      expect(first.display_id).to eq(1)
      expect(second.display_id).to eq(2)
    end

    it 'keeps independent sequences per account' do
      ticket_a = create(:ticket)
      ticket_b = create(:ticket)

      expect(ticket_a.display_id).to eq(1)
      expect(ticket_b.display_id).to eq(1)
    end
  end

  describe '#resolve! / #reopen! / #close!' do
    let(:user) { create(:user) }
    let(:ticket) { create(:ticket) }

    it 'resolves an open ticket and logs an activity' do
      ticket.resolve!(user)

      expect(ticket.status).to eq('resolved')
      expect(ticket.resolved_at).to be_present
      expect(ticket.ticket_activities.last.activity_type).to eq('resolved')
    end

    it 'is a no-op when already resolved' do
      ticket.resolve!(user)
      resolved_at = ticket.resolved_at

      expect { ticket.resolve!(user) }.not_to(change { ticket.reload.resolved_at })
      expect(ticket.reload.resolved_at).to eq(resolved_at)
    end

    it 'closes a resolved ticket' do
      make_ticket_closeable!(ticket, user: user)
      ticket.resolve!(user)
      ticket.close!(user)

      expect(ticket.status).to eq('closed')
      expect(ticket.closed_at).to be_present
      expect(ticket.ticket_activities.last.activity_type).to eq('closed')
    end

    it 'reopens a resolved or closed ticket' do
      ticket.resolve!(user)
      ticket.reopen!(user)

      expect(ticket.status).to eq('open')
      expect(ticket.ticket_activities.last.activity_type).to eq('reopened')
    end
  end

  describe '#ensure_checklist_completed!' do
    let(:ticket) { create(:ticket) }

    it 'blocks resolve! while a checklist item is pending' do
      ticket.ticket_checklist_items.create!(account: ticket.account, title: 'Confirmar dados', required: true)

      expect { ticket.resolve! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(ticket.reload.status).to eq('open')
    end

    it 'allows resolve! once every checklist item is completed' do
      item = ticket.ticket_checklist_items.create!(account: ticket.account, title: 'Confirmar dados', required: true)
      item.toggle!

      expect { ticket.resolve! }.not_to raise_error
      expect(ticket.reload.status).to eq('resolved')
    end

    it 'bypasses a pending checklist when the ticket has a linked Apontamento' do
      ticket.ticket_checklist_items.create!(account: ticket.account, title: 'Confirmar dados', required: true)
      event = CalendarEvent.create!(
        account: ticket.account, team: ticket.team, title: 'Ligação',
        start_at: Time.zone.now, end_at: 1.hour.from_now
      )
      ticket.calendar_events << event

      expect { ticket.resolve! }.not_to raise_error
      expect(ticket.reload.status).to eq('resolved')
    end
  end

  describe '#missing_close_requirements' do
    it 'includes checklist when items are pending and no Apontamento exists' do
      ticket = create(:ticket)
      ticket.ticket_checklist_items.create!(account: ticket.account, title: 'Confirmar dados', required: true)

      expect(ticket.missing_close_requirements).to include('checklist')
    end

    it 'omits checklist once an Apontamento is linked' do
      ticket = create(:ticket)
      ticket.ticket_checklist_items.create!(account: ticket.account, title: 'Confirmar dados', required: true)
      event = CalendarEvent.create!(
        account: ticket.account, team: ticket.team, title: 'Ligação',
        start_at: Time.zone.now, end_at: 1.hour.from_now
      )
      ticket.calendar_events << event

      expect(ticket.missing_close_requirements).not_to include('checklist')
    end
  end

  describe '#move_to! column rules' do
    it 'blocks the move when the target column requires a due date that is missing' do
      ticket = create(:ticket, due_date: nil)
      target = create(:ticket_column, team: ticket.team, require_due_date: true)

      expect { ticket.move_to!(ticket_column: target, position: 0) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(ticket.reload.ticket_column).not_to eq(target)
    end

    it 'blocks the move when the target column requires an assignee that is missing' do
      ticket = create(:ticket, assignee: nil)
      target = create(:ticket_column, team: ticket.team, require_assignee: true)

      expect { ticket.move_to!(ticket_column: target, position: 0) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'allows the move once the required field is present' do
      ticket = create(:ticket, due_date: 2.days.from_now)
      target = create(:ticket_column, team: ticket.team, require_due_date: true)

      expect { ticket.move_to!(ticket_column: target, position: 0) }.not_to raise_error
      expect(ticket.reload.ticket_column).to eq(target)
    end
  end

  describe 'change tracking' do
    it 'logs an activity when the assignee changes' do
      agent = create(:user)
      ticket = create(:ticket)

      expect { ticket.update!(assignee_id: agent.id) }
        .to change(ticket.ticket_activities, :count).by(1)
      expect(ticket.ticket_activities.last.activity_type).to eq('assignee_changed')
    end

    it 'logs a column_changed activity when moved to another column of the same Mesa' do
      ticket = create(:ticket)
      other_column = create(:ticket_column, team: ticket.ticket_column.team)

      ticket.move_to!(ticket_column: other_column, position: 0)

      expect(ticket.ticket_activities.last.activity_type).to eq('column_changed')
    end

    it 'also syncs team_id when moved to a column of a different Mesa' do
      ticket = create(:ticket)
      other_team = create(:team, account: ticket.account)
      other_team_column = create(:ticket_column, team: other_team)

      ticket.move_to!(ticket_column: other_team_column, position: 0)

      expect(ticket.reload.team_id).to eq(other_team_column.team_id)
      expect(ticket.ticket_activities.pluck(:activity_type)).to include('team_changed')
    end
  end

  describe 'Mesa (team) consistency' do
    it 'is invalid when team does not match the ticket_column team' do
      column = create(:ticket_column)
      other_team = create(:team)

      ticket = build(:ticket, ticket_column: column, team: other_team)

      expect(ticket).not_to be_valid
      expect(ticket.errors[:team]).to be_present
    end
  end
end
