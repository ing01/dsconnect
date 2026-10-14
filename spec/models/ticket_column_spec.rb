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
    it 'includes the team id and the column rule flags' do
      column = create(:ticket_column, name: 'Aberto')

      expect(column.push_event_data).to eq(
        id: column.id,
        name: 'Aberto',
        position: column.position,
        team_id: column.team_id,
        stage_threshold: column.stage_threshold,
        kind: 'normal',
        require_due_date: false,
        require_scheduled_at: false,
        require_appointment: false,
        require_assignee: false
      )
    end
  end

  describe '.preload_board_tickets!' do
    it 'keeps each column at its own BOARD_TICKETS_LIMIT instead of sharing one across the Mesa' do
      team = create(:team)
      stub_const('TicketColumn::BOARD_TICKETS_LIMIT', 3)
      first_column = create(:ticket_column, team: team, kind: 'normal')
      second_column = create(:ticket_column, team: team, kind: 'normal')
      # Mais tickets na primeira coluna do que o limite - se o corte vazar para
      # a Mesa toda (em vez de valer por coluna), ele consome o espaco da
      # segunda coluna mesmo ela tendo bem menos tickets do que o limite.
      create_list(:ticket, 5, ticket_column: first_column, team: team)
      create_list(:ticket, 2, ticket_column: second_column, team: team)

      described_class.preload_board_tickets!([first_column, second_column])

      expect(first_column.board_tickets.size).to eq(3)
      expect(second_column.board_tickets.size).to eq(2)
    end

    it 'does not hide a ticket sitting further down its own column just because other Estagios have lower positions' do
      team = create(:team)
      stub_const('TicketColumn::BOARD_TICKETS_LIMIT', 3)
      crowded_column = create(:ticket_column, team: team, kind: 'normal')
      target_column = create(:ticket_column, team: team, kind: 'normal')
      create_list(:ticket, 10, ticket_column: crowded_column, team: team)
      tickets = create_list(:ticket, 3, ticket_column: target_column, team: team)
      wanted = tickets.last

      described_class.preload_board_tickets!([crowded_column, target_column])

      expect(target_column.board_tickets.map(&:id)).to include(wanted.id)
    end

    it 'matches calling board_tickets on a single column directly (no preload involved)' do
      team = create(:team)
      column = create(:ticket_column, team: team, kind: 'normal')
      other_column = create(:ticket_column, team: team, kind: 'normal')
      create_list(:ticket, 4, ticket_column: other_column, team: team)
      expected = create_list(:ticket, 4, ticket_column: column, team: team)

      described_class.preload_board_tickets!([column, other_column])

      expect(column.board_tickets.map(&:id)).to eq(expected.map(&:id))
    end
  end

  describe 'kind' do
    it 'defaults to normal' do
      expect(create(:ticket_column).kind).to eq('normal')
    end

    it 'rejects a Mesa having two pending columns' do
      team = create(:team)
      team.ticket_columns.where(kind: 'pending').destroy_all
      create(:ticket_column, team: team, kind: 'pending')

      duplicate = build(:ticket_column, team: team, kind: 'pending')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to be_present
    end

    it 'rejects a Mesa having two completed columns' do
      team = create(:team)
      team.ticket_columns.where(kind: 'completed').destroy_all
      create(:ticket_column, team: team, kind: 'completed')

      duplicate = build(:ticket_column, team: team, kind: 'completed')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to be_present
    end

    it 'allows any number of normal columns' do
      team = create(:team)

      expect(create(:ticket_column, team: team, kind: 'normal')).to be_valid
      expect(create(:ticket_column, team: team, kind: 'normal')).to be_valid
    end

    it 'blocks destroying the mandatory Pendente/Finalizado columns' do
      team = create(:team)
      pending_column = team.ticket_columns.find_by(kind: 'pending')

      expect(pending_column.destroy).to be false
      expect(pending_column.errors[:base]).to be_present
    end
  end
end
