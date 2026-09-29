require 'rails_helper'

RSpec.describe SuggestionCategory do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:suggestions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'accepts a color from the shared label palette' do
      category = build(:suggestion_category, color: 'blue')
      expect(category).to be_valid
    end

    it 'rejects a color outside the shared label palette' do
      category = build(:suggestion_category, color: 'green')
      expect(category).not_to be_valid
      expect(category.errors[:color]).to be_present
    end
  end

  describe 'default position' do
    it 'assigns the next position within the account when not set' do
      account = create(:account)
      create(:suggestion_category, account: account)
      base_position = account.suggestion_categories.maximum(:position)

      category = create(:suggestion_category, account: account)

      expect(category.position).to eq(base_position + 1)
    end
  end

  describe 'destroy behaviour' do
    it 'clears the category from suggestions instead of blocking deletion' do
      category = create(:suggestion_category)
      suggestion = create(:suggestion, category: category, account: category.account,
                                        suggestion_column: create(:suggestion_column, account: category.account))

      category.destroy!

      expect(suggestion.reload.category_id).to be_nil
    end
  end
end
