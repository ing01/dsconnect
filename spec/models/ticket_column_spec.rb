require 'rails_helper'

RSpec.describe TicketColumn do
  describe 'associations' do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_many(:tickets) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'default position' do
    it 'assigns the next position within the team when not set' do
      team = create(:team)
      base_position = team.ticket_columns.maximum(:position)

      column = create(:ticket_column, team: team)

      expect(column.position).to eq(base_position + 1)
    end

    it 'starts right after the Mesa (Team) default Estagios' do
      team = create(:team)
      defaults_count = team.ticket_columns.count

      column = create(:ticket_column, team: team)

      expect(column.position).to eq(defaults_count)
    end
  end

  describe 'destroy behaviour' do
    it 'is restricted while it still has tickets' do
      column = create(:ticket_column)
      create(:ticket, ticket_column: column, team: column.team)

      expect(column.destroy).to be false
      expect(column.errors[:base]).to be_present
    end

    it 'can be destroyed once it has no tickets' do
      column = create(:ticket_column)
      expect(column.destroy).to eq(column)
    end
  end

  describe '.reorder!' do
    it 'persists a new column order for the given team' do
      team = create(:team)
      team.ticket_columns.destroy_all
      first = create(:ticket_column, team: team, position: 0)
      second = create(:ticket_column, team: team, position: 1)

      described_class.reorder!(team, [second.id, first.id])

      expect(second.reload.position).to eq(0)
      expect(first.reload.position).to eq(1)
    end
  end

  describe '#push_event_data' do
    it 'includes the team id' do
      column = create(:ticket_column, name: 'Aberto')

      expect(column.push_event_data).to eq(
        id: column.id,
        name: 'Aberto',
        position: column.position,
        team_id: column.team_id
      )
    end
  end
end
