require 'rails_helper'

RSpec.describe TicketBoard do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:ticket_columns) }
    it { is_expected.to have_many(:tickets) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe '#ticket_columns' do
    it 'orders columns by position' do
      board = create(:ticket_board)
      third = create(:ticket_column, ticket_board: board, position: 2)
      first = create(:ticket_column, ticket_board: board, position: 0)
      second = create(:ticket_column, ticket_board: board, position: 1)

      expect(board.ticket_columns).to eq([first, second, third])
    end
  end

  describe '#push_event_data' do
    it 'includes the board and its columns' do
      board = create(:ticket_board, name: 'Suporte')
      column = create(:ticket_column, ticket_board: board, name: 'Aberto')

      expect(board.push_event_data).to eq(
        id: board.id,
        name: 'Suporte',
        ticket_columns: [{ id: column.id, name: 'Aberto', position: column.position }]
      )
    end
  end
end
