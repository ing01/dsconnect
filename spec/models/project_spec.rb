require 'rails_helper'

RSpec.describe Project do
  # `create(:ticket, team: project.team)` alone would leave the ticket's
  # `ticket_column` pointing at a different (factory-created) team, which
  # `Ticket#team_matches_ticket_column` rejects - pinning `ticket_column` to
  # one of the project's own Mesa keeps `team` consistent via the ticket
  # factory's own `team ||= ticket_column.team`.
  def create_project_ticket(project, **attrs)
    create(:ticket, project: project, ticket_column: project.team.ticket_columns.first, **attrs)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:team) }
    it { is_expected.to belong_to(:company).optional }
    it { is_expected.to belong_to(:project_module).optional }
    it { is_expected.to have_many(:tickets) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:stage).in_array(Project::STAGES) }
  end

  describe '#advance_stage!' do
    it 'moves the project to a known stage' do
      project = create(:project, stage: 'onboarding')

      project.advance_stage!('em_andamento')

      expect(project.reload.stage).to eq('em_andamento')
    end

    it 'ignores an unknown stage' do
      project = create(:project, stage: 'onboarding')

      project.advance_stage!('not_a_stage')

      expect(project.reload.stage).to eq('onboarding')
    end
  end

  describe 'status/stage sync' do
    it 'marks the project completed once it reaches finalizado' do
      project = create(:project, stage: 'pos')

      project.advance_stage!('finalizado')

      expect(project.reload.status).to eq('completed')
    end
  end

  describe 'conclusão travada por tickets pendentes' do
    it 'rejects setting stage to finalizado while a ticket is still open' do
      project = create(:project, stage: 'pos')
      create_project_ticket(project)

      project.stage = 'finalizado'

      expect(project).not_to be_valid
      expect(project.errors[:stage]).to be_present
    end

    it 'allows finalizado once every ticket is resolved/closed/cancelled' do
      project = create(:project, stage: 'pos')
      ticket = create_project_ticket(project)
      ticket.update!(status: :resolved)

      project.stage = 'finalizado'

      expect(project).to be_valid
    end

    it '#advance_stage! silently stays put instead of raising when tickets are still open' do
      project = create(:project, stage: 'pos')
      create_project_ticket(project)

      expect { project.advance_stage!('finalizado') }.not_to raise_error
      expect(project.reload.stage).to eq('pos')
    end
  end

  describe '#total_hours' do
    it 'sums TicketTimeEntry hours across every ticket of the project' do
      project = create(:project)
      first_ticket = create_project_ticket(project)
      second_ticket = create_project_ticket(project)
      agent = create(:user, account: project.account)

      create(:ticket_time_entry, ticket: first_ticket, account: project.account, user: agent, hours: 2)
      create(:ticket_time_entry, ticket: second_ticket, account: project.account, user: agent, hours: 1.5)

      expect(project.total_hours).to eq(3.5)
    end
  end

  describe 'board scopes' do
    it 'keeps finalizado projects out of the active board' do
      active = create(:project, stage: 'onboarding')
      finished = create(:project, stage: 'finalizado')

      expect(described_class.active_board).to include(active)
      expect(described_class.active_board).not_to include(finished)
      expect(described_class.completed_board).to include(finished)
      expect(described_class.completed_board).not_to include(active)
    end
  end
end
