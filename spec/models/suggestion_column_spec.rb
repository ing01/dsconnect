require 'rails_helper'

RSpec.describe SuggestionColumn do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:suggestions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'completed flag' do
    it 'defaults to false' do
      expect(create(:suggestion_column).completed?).to be(false)
    end
  end

  describe 'default position' do
    it 'assigns the next position within the account when not set' do
      account = create(:account)
      create(:suggestion_column, account: account)
      base_position = account.suggestion_columns.maximum(:position)

      column = create(:suggestion_column, account: account)

      expect(column.position).to eq(base_position + 1)
    end
  end

  describe 'destroy behaviour' do
    it 'is restricted while it still has suggestions' do
      column = create(:suggestion_column)
      create(:suggestion, suggestion_column: column, account: column.account)

      expect(column.destroy).to be false
      expect(column.errors[:base]).to be_present
    end

    it 'can be destroyed once it has no suggestions' do
      column = create(:suggestion_column)
      expect(column.destroy).to eq(column)
    end
  end

  describe '.reorder!' do
    it 'persists a new column order for the given account' do
      account = create(:account)
      first = create(:suggestion_column, account: account, position: 0)
      second = create(:suggestion_column, account: account, position: 1)

      described_class.reorder!(account, [second.id, first.id])

      expect(second.reload.position).to eq(0)
      expect(first.reload.position).to eq(1)
    end
  end
end
