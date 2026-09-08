require 'rails_helper'

RSpec.describe V2::Reports::Implementation::HoursSummaryBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:agent) { create(:user, account: account) }

  def create_project_ticket(project, **attrs)
    create(:ticket, project: project, ticket_column: project.team.ticket_columns.first, **attrs)
  end

  it 'sums hours by category across the filtered projects' do
    project = create(:project, account: account, team: team, start_date: Date.current)
    ticket = create_project_ticket(project)
    create(:ticket_time_entry, ticket: ticket, account: account, user: agent, category: 'implantacao', hours: 3)
    create(:ticket_time_entry, ticket: ticket, account: account, user: agent, category: 'desenvolvimento', hours: 2)

    result = described_class.new(account: account, params: {}).build

    expect(result[:total_hours]).to eq(5.0)
    expect(result[:by_category]['implantacao']).to eq(3.0)
    expect(result[:by_category]['desenvolvimento']).to eq(2.0)
    expect(result[:by_category]['dev_geral']).to eq(0.0)
  end

  it 'ignores projects outside the filtered set' do
    other_team = create(:team, account: account)
    project = create(:project, account: account, team: team, implementer: agent)
    create(:project, account: account, team: other_team)
    ticket = create_project_ticket(project)
    create(:ticket_time_entry, ticket: ticket, account: account, user: agent, hours: 4)

    result = described_class.new(account: account, params: { implementer_id: agent.id }).build

    expect(result[:total_hours]).to eq(4.0)
    expect(result[:projects_count]).to eq(1)
  end
end
