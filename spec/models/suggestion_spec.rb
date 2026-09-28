require 'rails_helper'

RSpec.describe Suggestion do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:suggestion_column) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }

    it 'rejects a suggestion_column from another account' do
      other_account_column = create(:suggestion_column)
      suggestion = build(:suggestion, suggestion_column: other_account_column, account: create(:account))

      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:suggestion_column]).to be_present
    end
  end

  describe 'default position' do
    it 'lands at the end of its column' do
      column = create(:suggestion_column)
      create(:suggestion, suggestion_column: column, account: column.account)

      second = create(:suggestion, suggestion_column: column, account: column.account)

      expect(second.position).to eq(1)
    end
  end

  describe 'notification on create' do
    it 'enqueues a job to notify the account administrators' do
      column = create(:suggestion_column)

      expect { create(:suggestion, suggestion_column: column, account: column.account) }
        .to have_enqueued_job(Suggestions::AdminNotificationJob)
    end
  end

  describe '#move_to!' do
    it 'moves the suggestion to another column and reindexes both columns' do
      account = create(:account)
      origin = create(:suggestion_column, account: account)
      destination = create(:suggestion_column, account: account)
      moved = create(:suggestion, suggestion_column: origin, account: account)
      staying = create(:suggestion, suggestion_column: origin, account: account)

      moved.move_to!(suggestion_column: destination, position: 0)

      expect(moved.reload.suggestion_column).to eq(destination)
      expect(moved.position).to eq(0)
      expect(staying.reload.position).to eq(0)
    end
  end

  describe '#push_event_data' do
    it 'includes the submitter name' do
      user = create(:user, name: 'Maria')
      suggestion = create(:suggestion, user: user, title: 'Melhoria X')

      data = suggestion.push_event_data

      expect(data[:title]).to eq('Melhoria X')
      expect(data[:user_name]).to eq('Maria')
      expect(data[:suggestion_column_id]).to eq(suggestion.suggestion_column_id)
    end
  end
end
