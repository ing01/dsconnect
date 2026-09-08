require 'rails_helper'

RSpec.describe Implementation::OverdueDateNotificationBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:implementer) { create(:user, account: account) }
  let(:project) { create(:project, account: account, team: team, implementer: implementer) }

  it 'notifies the responsible implementer' do
    expect do
      described_class.new(project: project, notification_type: 'project_contract_end_overdue').perform
    end.to change(Notification, :count).by(1)

    notification = Notification.last
    expect(notification.user).to eq(implementer)
    expect(notification.primary_actor).to eq(project)
    expect(notification.notification_type).to eq('project_contract_end_overdue')
  end

  it 'falls back to the team manager when there is no implementer' do
    manager = create(:user, account: account)
    team.update!(manager: manager)
    project.update!(implementer: nil)

    expect do
      described_class.new(project: project, notification_type: 'project_contract_end_overdue').perform
    end.to change(Notification, :count).by(1)

    expect(Notification.last.user).to eq(manager)
  end

  it 'does nothing when there is no recipient at all' do
    project.update!(implementer: nil)

    expect do
      described_class.new(project: project, notification_type: 'project_contract_end_overdue').perform
    end.not_to change(Notification, :count)
  end

  it 'does not duplicate an unread notification for the same project/type' do
    described_class.new(project: project, notification_type: 'project_contract_end_overdue').perform

    expect do
      described_class.new(project: project, notification_type: 'project_contract_end_overdue').perform
    end.not_to change(Notification, :count)
  end

  it 'notifies again once the previous notification was read' do
    described_class.new(project: project, notification_type: 'project_contract_end_overdue').perform
    Notification.last.update!(read_at: Time.current)

    expect do
      described_class.new(project: project, notification_type: 'project_contract_end_overdue').perform
    end.to change(Notification, :count).by(1)
  end
end
