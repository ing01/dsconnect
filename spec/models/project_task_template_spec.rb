require 'rails_helper'

RSpec.describe ProjectTaskTemplate do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:default_assignee).optional }
    it { is_expected.to belong_to(:checklist).optional }
    it { is_expected.to have_many(:project_module_task_templates) }
    it { is_expected.to have_many(:project_modules) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:default_ticket_title) }
    it { is_expected.to validate_numericality_of(:due_days).is_greater_than_or_equal_to(0) }
  end
end
