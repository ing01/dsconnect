require 'rails_helper'

RSpec.describe V2::Reports::Implementation::ImplementerReportBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:implementer) { create(:user, account: account) }

  it 'rolls up projects and hours per implementer, and a period-independent capacity table' do
    active = create(:project, account: account, team: team, implementer: implementer, stage: 'onboarding')
    create(:project, account: account, team: team, implementer: implementer, stage: 'finalizado') # out of capacity
    unassigned = create(:project, account: account, team: team, stage: 'onboarding')

    result = described_class.new(account: account, params: {}).build
    by_implementer = result[:by_implementer].index_by { |row| row[:implementer_id] }
    capacity = result[:capacity].index_by { |row| row[:implementer_id] }

    expect(by_implementer[implementer.id][:projects_count]).to eq(2)
    expect(capacity[implementer.id][:projects_count]).to eq(1) # finalizado excluded
    expect(capacity[nil][:projects_count]).to eq(1)
    expect(unassigned).to be_present
  end
end
