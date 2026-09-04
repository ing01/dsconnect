require 'rails_helper'

RSpec.describe TicketChecklistItem do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:completed_by).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_inclusion_of(:item_type).in_array(described_class::ITEM_TYPES) }
  end

  describe 'defaults' do
    it 'is a checkbox, not required, by default' do
      item = create(:ticket_checklist_item)

      expect(item.item_type).to eq('checkbox')
      expect(item.required).to be false
    end
  end

  describe 'checkbox items' do
    it 'are completed only by #toggle!, never by setting value' do
      item = create(:ticket_checklist_item, item_type: 'checkbox')

      item.update!(value: 'anything')

      expect(item.reload.completed).to be false
    end

    it 'flips completed and records who/when on #toggle!' do
      item = create(:ticket_checklist_item, item_type: 'checkbox')
      user = create(:user)

      item.toggle!(user)

      expect(item.reload).to be_completed
      expect(item.completed_by).to eq(user)
      expect(item.completed_at).to be_present
    end
  end

  describe 'text/number/single_select items' do
    it 'become completed as soon as a value is set' do
      item = create(:ticket_checklist_item, item_type: 'text')

      item.update!(value: 'ok')

      expect(item.reload).to be_completed
    end

    it 'become pending again if the value is cleared' do
      item = create(:ticket_checklist_item, item_type: 'number', value: '10')

      item.update!(value: '')

      expect(item.reload.completed).to be false
    end
  end
end
