require 'rails_helper'

RSpec.describe ProjectModule do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:project_module_task_templates) }
    it { is_expected.to have_many(:project_task_templates) }
    it { is_expected.to have_many(:projects) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'task templates' do
    it 'keeps the templates in position order' do
      account = create(:account)
      project_module = create(:project_module, account: account)
      first_template = create(:project_task_template, account: account)
      second_template = create(:project_task_template, account: account)

      project_module.project_module_task_templates.create!(project_task_template: second_template, position: 0)
      project_module.project_module_task_templates.create!(project_task_template: first_template, position: 1)

      expect(project_module.reload.project_task_templates).to eq([second_template, first_template])
    end
  end
end
