require 'rails_helper'

RSpec.describe V2::Reports::Implementation::MonthlyReportBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:agent) { create(:user, account: account) }

  it 'always covers the last 6 months, ignoring the period filter but not the other filters' do
    this_month_project = create(:project, account: account, team: team, start_date: Date.current.beginning_of_month)
    ticket = create(:ticket, project: this_month_project, ticket_column: team.ticket_columns.first)
    create(:ticket_time_entry, ticket: ticket, account: account, user: agent, hours: 5, worked_on: Date.current)

    old_project = create(:project, account: account, team: team, start_date: 2.years.ago)

    # since/until narrower than the current month - MonthlyReportBuilder must ignore it
    result = described_class.new(account: account, params: { since: 10.years.ago.to_i.to_s, until: 9.years.ago.to_i.to_s }).build

    expect(result.size).to eq(described_class::MONTHS_BACK)
    current_month_row = result.last
    expect(current_month_row[:month]).to eq(Date.current.strftime('%Y-%m'))
    expect(current_month_row[:clients_started]).to eq(1)
    expect(current_month_row[:hours_logged]).to eq(5.0)
    expect(old_project).to be_present
  end
end
