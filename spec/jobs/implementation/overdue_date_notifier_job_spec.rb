require 'rails_helper'

RSpec.describe Implementation::OverdueDateNotifierJob do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:implementer) { create(:user, account: account) }

  it 'notifies overdue contract-end projects still in an early stage' do
    overdue = create(:project, account: account, team: team, implementer: implementer, stage: 'onboarding', due_date: 1.day.ago)
    not_overdue = create(:project, account: account, team: team, implementer: implementer, stage: 'onboarding', due_date: 1.day.from_now)
    wrong_stage = create(:project, account: account, team: team, implementer: implementer, stage: 'acompanhamento', due_date: 1.day.ago)

    described_class.perform_now

    expect(Notification.where(primary_actor: overdue, notification_type: 'project_contract_end_overdue').count).to eq(1)
    expect(Notification.where(primary_actor: not_overdue).count).to eq(0)
    expect(Notification.where(primary_actor: wrong_stage, notification_type: 'project_contract_end_overdue').count).to eq(0)
  end

  it 'notifies overdue support-end projects in acompanhamento' do
    overdue = create(:project, account: account, team: team, implementer: implementer, stage: 'acompanhamento', support_ends_on: 1.day.ago)

    described_class.perform_now

    notification = Notification.find_by(primary_actor: overdue)
    expect(notification.notification_type).to eq('project_support_end_overdue')
  end
end
