require 'rails_helper'

RSpec.describe TicketColumn do
  describe 'associations' do
    it { is_expected.to belong_to(:ticket_board) }
    it { is_expected.to have_many(:tickets) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'default position' do
    it 'assigns the next position within the board when not set' do
      board = create(:ticket_board)
      create(:ticket_column, ticket_board: board, position: 0)

      column = create(:ticket_column, ticket_board: board)

      expect(column.position).to eq(1)
    end

    it 'starts at 0 for the first column of a board' do
      column = create(:ticket_column, ticket_board: create(:ticket_board))
      expect(column.position).to eq(0)
    end
  end

  describe 'destroy behaviour' do
    it 'is restricted while it still has tickets' do
      column = create(:ticket_column)
      create(:ticket, ticket_column: column)

      expect(column.destroy).to be false
      expect(column.errors[:base]).to be_present
    end

    it 'can be destroyed once it has no tickets' do
      column = create(:ticket_column)
      expect(column.destroy).to eq(column)
    end
  end
end
