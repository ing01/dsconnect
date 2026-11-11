require 'rails_helper'

# O cronometro de apontamento: inicia, pausa, continua e, ao finalizar, vira horas
# lancadas (TicketTimeEntry). Enquanto corre nao conta em total nenhum.
RSpec.describe TicketTimer do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, ticket_column: column) }
  let(:other_ticket) { create(:ticket, ticket_column: column) }
  let(:agent) { create(:user, account: account) }

  describe 'validations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_inclusion_of(:category).in_array(TicketTimeEntry::CATEGORIES) }

    it 'allows only one timer per person per ticket' do
      described_class.start!(ticket: ticket, user: agent)

      duplicate = build(:ticket_timer, ticket: ticket, account: account, user: agent)

      expect(duplicate).not_to be_valid
    end
  end

  describe '.start!' do
    it 'starts running with nothing accumulated' do
      timer = described_class.start!(ticket: ticket, user: agent, category: 'desenvolvimento', note: ' ajustando ')

      expect(timer).to be_running
      expect(timer).to have_attributes(accumulated_seconds: 0, category: 'desenvolvimento', note: 'ajustando', status: 'running')
    end

    it 'pauses the timer that was running in another ticket, keeping its time' do
      first = nil
      travel_to(Time.zone.local(2026, 11, 11, 9, 0, 0)) { first = described_class.start!(ticket: ticket, user: agent) }

      travel_to(Time.zone.local(2026, 11, 11, 9, 30, 0)) { described_class.start!(ticket: other_ticket, user: agent) }

      expect(first.reload).not_to be_running
      expect(first.accumulated_seconds).to eq(30 * 60)
    end

    it 'does not touch the timers of other people' do
      colleague = create(:user, account: account)
      theirs = described_class.start!(ticket: ticket, user: colleague)

      described_class.start!(ticket: other_ticket, user: agent)

      expect(theirs.reload).to be_running
    end
  end

  describe 'pause and resume' do
    it 'counts only the time while running' do
      timer = nil
      travel_to(Time.zone.local(2026, 11, 11, 9, 0, 0)) { timer = described_class.start!(ticket: ticket, user: agent) }
      travel_to(Time.zone.local(2026, 11, 11, 9, 10, 0)) { timer.pause! }
      travel_to(Time.zone.local(2026, 11, 11, 11, 0, 0)) do
        expect(timer.reload.elapsed_seconds).to eq(10 * 60) # parado: nao corre
        timer.resume!
      end
      travel_to(Time.zone.local(2026, 11, 11, 11, 5, 0)) do
        expect(timer.reload.elapsed_seconds).to eq(15 * 60)
      end
    end

    it 'pausing a paused timer changes nothing' do
      timer = create(:ticket_timer, ticket: ticket, account: account, user: agent, accumulated_seconds: 120)

      expect { timer.pause! }.not_to(change { timer.reload.accumulated_seconds })
    end

    it 'resuming pauses the other running timer of the same person' do
      running = described_class.start!(ticket: ticket, user: agent)
      paused = create(:ticket_timer, ticket: other_ticket, account: account, user: agent)

      paused.resume!

      expect(running.reload).not_to be_running
      expect(paused.reload).to be_running
    end
  end

  describe '#finish!' do
    it 'turns the elapsed time into a regular time entry and removes the timer' do
      timer = nil
      travel_to(Time.zone.local(2026, 11, 11, 9, 0, 0)) do
        timer = described_class.start!(ticket: ticket, user: agent, category: 'desenvolvimento', note: 'tela de pedidos')
      end

      entry = nil
      travel_to(Time.zone.local(2026, 11, 11, 10, 30, 0)) do
        expect { entry = timer.finish! }.to change(TicketTimeEntry, :count).by(1).and change(described_class, :count).by(-1)
      end

      expect(entry).to have_attributes(
        ticket_id: ticket.id, user_id: agent.id, category: 'desenvolvimento', note: 'tela de pedidos',
        hours: 1.5, worked_on: Date.new(2026, 11, 11)
      )
    end

    it 'rounds to 2 decimals' do
      timer = create(:ticket_timer, ticket: ticket, account: account, user: agent, accumulated_seconds: 17 * 60)

      expect(timer.finish!.hours).to eq(0.28)
    end

    it 'never lets less than the minimum through' do
      timer = create(:ticket_timer, ticket: ticket, account: account, user: agent, accumulated_seconds: 3)

      expect(timer.finish!.hours).to eq(described_class::MIN_HOURS)
    end

    it 'keeps the timer if the entry cannot be saved' do
      timer = create(:ticket_timer, ticket: ticket, account: account, user: agent, accumulated_seconds: 600)
      allow(timer.ticket.ticket_time_entries).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { timer.finish! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(described_class.exists?(timer.id)).to be(true)
    end
  end

  describe 'running timers and the totals' do
    it 'a running timer is not counted as hours worked' do
      described_class.start!(ticket: ticket, user: agent)

      expect(ticket.ticket_time_entries.sum(:hours)).to eq(0)
    end
  end
end
