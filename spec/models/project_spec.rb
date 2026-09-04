require 'rails_helper'

RSpec.describe Project do
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
