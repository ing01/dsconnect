require 'rails_helper'

RSpec.describe Checklist do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:project_task_templates) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'defaults' do
    it 'starts with no items' do
      expect(create(:checklist).items).to eq([])
    end
  end

  describe 'destroy behaviour' do
    it 'nullifies task templates that referenced it, rather than blocking the delete' do
      checklist = create(:checklist)
      template = create(:project_task_template, checklist: checklist)

      checklist.destroy!

      expect(template.reload.checklist_id).to be_nil
    end
  end
end
