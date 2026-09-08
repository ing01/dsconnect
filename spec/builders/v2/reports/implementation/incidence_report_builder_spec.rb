require 'rails_helper'

RSpec.describe V2::Reports::Implementation::IncidenceReportBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }

  def create_project_ticket(project, **attrs)
    create(:ticket, project: project, ticket_column: project.team.ticket_columns.first, **attrs)
  end

  it 'classifies projects in pós by ticket count, and ignores projects outside pós stages' do
    normal = create(:project, account: account, team: team, stage: 'acompanhamento')
    3.times { create_project_ticket(normal) }

    critico = create(:project, account: account, team: team, stage: 'pos')
    13.times { create_project_ticket(critico) }

    outside_pos = create(:project, account: account, team: team, stage: 'em_andamento')
    20.times { create_project_ticket(outside_pos) }

    result = described_class.new(account: account, params: {}).build
    by_project = result.index_by { |row| row[:project_id] }

    expect(by_project[normal.id][:classification]).to eq('normal')
    expect(by_project[normal.id][:reincidente]).to be true
    expect(by_project[critico.id][:classification]).to eq('critico')
    expect(by_project).not_to have_key(outside_pos.id)
  end
end
