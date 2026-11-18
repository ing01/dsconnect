require 'rails_helper'

RSpec.describe Tickets::ChildCompletedNotificationBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account, development_module_enabled: true) }
  let(:column) { create(:ticket_column, team: team) }
  let(:analyst) { create(:user, account: account, role: :agent) }
  let(:parent) { create(:ticket, account: account, ticket_column: column, team: team, assignee: analyst) }
  let(:child) { create(:ticket, account: account, ticket_column: column, team: team, parent: parent, title: 'Ajustar relatório') }

  def perform
    described_class.new(ticket: child).perform
  end

  it 'notifies the assignee of the parent, opening the parent' do
    expect { perform }.to change { analyst.notifications.where(notification_type: 'ticket_child_completed').count }.by(1)

    notification = analyst.notifications.find_by(notification_type: 'ticket_child_completed')
    expect(notification.primary_actor).to eq(parent)
    expect(notification.secondary_actor).to eq(child)
    expect(notification.push_target_path).to eq("/app/accounts/#{account.id}/tickets/#{parent.id}")
  end

  it 'leaves a note in the history of the parent' do
    perform

    note = parent.ticket_activities.where(activity_type: :automation_note).last
    expect(note.new_value).to include("##{child.display_id}", 'Ajustar relatório', 'concluído')
  end

  it 'marks the parent card with the completed child, even without an assignee' do
    parent.update!(assignee: nil)

    perform

    expect(parent.reload.child_completed_at).to be_present
    expect(parent.child_completed_display_id).to eq(child.display_id)
  end

  it 'broadcasts the mark so the Kanban shows it live' do
    perform

    expect(parent.reload.push_event_data).to include(child_completed_display_id: child.display_id)
    expect(parent.push_event_data[:child_completed_at]).to be_a(Integer)
  end

  it 'keeps only the note when the parent has no assignee' do
    parent.update!(assignee: nil)

    expect { perform }.not_to change(Notification, :count)
    expect(parent.ticket_activities.where(activity_type: :automation_note)).to exist
  end

  it 'does nothing when the parent is already closed' do
    parent.update_columns(status: Ticket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations

    expect { perform }.not_to change(Notification, :count)
    expect(parent.ticket_activities.where(activity_type: :automation_note)).to be_empty
    expect(parent.reload.child_completed_at).to be_nil
  end

  it 'does nothing for a ticket without a parent' do
    expect { described_class.new(ticket: parent).perform }.not_to change(Notification, :count)
  end
end
