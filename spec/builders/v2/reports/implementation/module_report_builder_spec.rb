require 'rails_helper'

RSpec.describe V2::Reports::Implementation::ModuleReportBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:erp) { create(:project_module, account: account, name: 'ERP') }

  it 'computes % of projects and total hours per module' do
    p1 = create(:project, account: account, team: team, project_module: erp)
    p2 = create(:project, account: account, team: team, project_module: erp)
    create(:project, account: account, team: team, project_module: nil)

    agent = create(:user, account: account)
    ticket1 = create(:ticket, project: p1, ticket_column: team.ticket_columns.first)
    ticket2 = create(:ticket, project: p2, ticket_column: team.ticket_columns.first)
    create(:ticket_time_entry, ticket: ticket1, account: account, user: agent, hours: 2)
    create(:ticket_time_entry, ticket: ticket2, account: account, user: agent, hours: 3)

    result = described_class.new(account: account, params: {}).build
    erp_row = result.find { |row| row[:project_module_id] == erp.id }

    expect(erp_row[:projects_count]).to eq(2)
    expect(erp_row[:percentage]).to eq(66.7)
    expect(erp_row[:total_hours]).to eq(5.0)
  end
end
