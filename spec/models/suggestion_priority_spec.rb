require 'rails_helper'

RSpec.describe SuggestionPriority do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:suggestions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'accepts a color from the shared label palette' do
      priority = build(:suggestion_priority, color: 'ruby')
      expect(priority).to be_valid
    end

    it 'rejects a color outside the shared label palette' do
      priority = build(:suggestion_priority, color: 'green')
      expect(priority).not_to be_valid
      expect(priority.errors[:color]).to be_present
    end
  end

  describe 'default position' do
    it 'assigns the next position within the account when not set' do
      account = create(:account)
      create(:suggestion_priority, account: account)
      base_position = account.suggestion_priorities.maximum(:position)

      priority = create(:suggestion_priority, account: account)

      expect(priority.position).to eq(base_position + 1)
    end
  end

  describe 'destroy behaviour' do
    it 'clears the priority from suggestions instead of blocking deletion' do
      priority = create(:suggestion_priority)
      suggestion = create(:suggestion, priority: priority, account: priority.account,
                                        suggestion_column: create(:suggestion_column, account: priority.account))

      priority.destroy!

      expect(suggestion.reload.priority_id).to be_nil
    end
  end
end
