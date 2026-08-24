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

    it 'reports how many tickets are blocking the deletion' do
      column = create(:ticket_column)
      create_list(:ticket, 2, ticket_column: column, team: column.team)

      column.destroy

      expect(column.errors[:base].first).to include('2')
    end

    it 'can be destroyed once it has no tickets' do
      column = create(:ticket_column)
      expect(column.destroy).to eq(column)
    end
  end

  describe 'moving an Estagio to another Mesa' do
    let(:account) { create(:account) }
    let(:origin) { create(:team, account: account) }
    let(:destination) { create(:team, account: account) }

    it 'is rejected while the Estagio still has tickets' do
      column = create(:ticket_column, team: origin)
      create_list(:ticket, 3, ticket_column: column, team: origin)

      column.team = destination

      expect(column).not_to be_valid
      expect(column.errors[:base].first).to include('3')
    end

    it 'is allowed while the Estagio is empty' do
      column = create(:ticket_column, team: origin)

      expect(column.update(team: destination)).to be true
      expect(column.reload.team).to eq(destination)
    end

    it 'lands the Estagio at the end of the destination Mesa' do
      column = create(:ticket_column, team: origin)
      last_position = destination.ticket_columns.maximum(:position)

      column.update!(team: destination)

      expect(column.reload.position).to eq(last_position + 1)
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

  describe 'ordering' do
    it 'falls back to id when several Estagios share a position' do
      team = create(:team)
      team.ticket_columns.update_all(position: 0) # rubocop:disable Rails/SkipsModelValidations

      expect(team.reload.ticket_columns.pluck(:id)).to eq(team.ticket_columns.pluck(:id).sort)
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
