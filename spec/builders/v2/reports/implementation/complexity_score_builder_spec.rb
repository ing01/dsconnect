require 'rails_helper'

RSpec.describe V2::Reports::Implementation::ComplexityScoreBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:company) { create(:company, account: account) }
  let(:agent) { create(:user, account: account) }

  def create_project_ticket(project, **attrs)
    create(:ticket, project: project, ticket_column: project.team.ticket_columns.first, **attrs)
  end

  it 'scores hours + sibling projects*2 + tickets no pós*3' do
    project = create(:project, account: account, team: team, company: company, stage: 'acompanhamento')
    create(:project, account: account, team: team, company: company) # sibling, same company

    ticket = create_project_ticket(project)
    create(:ticket_time_entry, ticket: ticket, account: account, user: agent, hours: 10)
    create_project_ticket(project) # 2nd ticket, counts toward "no pós" since stage is acompanhamento

    result = described_class.new(account: account, params: {}).build
    row = result.find { |r| r[:project_id] == project.id }

    # 10 hours + 1 sibling*2 + 2 tickets no pós*3 = 18
    expect(row[:score]).to eq(18.0)
  end

  it 'has zero siblings/tickets contribution for a project without company or pós tickets' do
    project = create(:project, account: account, team: team, stage: 'onboarding')
    ticket = create_project_ticket(project)
    create(:ticket_time_entry, ticket: ticket, account: account, user: agent, hours: 4)

    result = described_class.new(account: account, params: {}).build
    row = result.find { |r| r[:project_id] == project.id }

    expect(row[:score]).to eq(4.0)
  end
end
