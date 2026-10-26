require 'rails_helper'

# O Sprint do Modulo de Desenvolvimento.
RSpec.describe Sprint do
  it 'requires a name' do
    sprint = build(:sprint, name: nil)
    expect(sprint).not_to be_valid
    expect(sprint.errors[:name]).to be_present
  end

  it 'requires ends_on to be on/after starts_on' do
    sprint = build(:sprint, starts_on: Date.current, ends_on: Date.current - 1.day)
    expect(sprint).not_to be_valid
    expect(sprint.errors[:ends_on]).to be_present
  end

  it 'allows ends_on equal to starts_on (a single-day sprint)' do
    sprint = build(:sprint, starts_on: Date.current, ends_on: Date.current)
    expect(sprint).to be_valid
  end

  it 'starts as upcoming by default' do
    expect(create(:sprint)).to be_upcoming
  end

  it 'nullifies tickets instead of destroying them when deleted' do
    sprint = create(:sprint)
    ticket = create(:ticket, ticket_column: create(:ticket_column, team: sprint.team), sprint: sprint)

    sprint.destroy!

    expect(Ticket.find(ticket.id).sprint_id).to be_nil
  end

  describe '#activate!' do
    it 'marks the sprint active' do
      sprint = create(:sprint)
      sprint.activate!
      expect(sprint.reload).to be_active
    end

    it 'demotes the Mesa previous active sprint back to upcoming' do
      team = create(:team)
      previous = create(:sprint, team: team, status: :active)
      next_one = create(:sprint, team: team, starts_on: previous.ends_on + 1.day, ends_on: previous.ends_on + 5.days)

      next_one.activate!

      expect(previous.reload).to be_upcoming
      expect(next_one.reload).to be_active
    end

    it 'refuses to activate a completed sprint' do
      sprint = create(:sprint, status: :completed)
      expect { sprint.activate! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#conclude!' do
    it 'marks the sprint completed' do
      sprint = create(:sprint)
      sprint.conclude!
      expect(sprint.reload).to be_completed
    end

    it 'moves tickets not yet in the final Estagio to the next sprint' do
      team = create(:team)
      sprint = create(:sprint, team: team, status: :active)
      next_sprint = create(:sprint, team: team, starts_on: sprint.ends_on + 1.day, ends_on: sprint.ends_on + 5.days)
      pending_column = create(:ticket_column, team: team, kind: 'normal')
      ticket = create(:ticket, ticket_column: pending_column, sprint: sprint)

      sprint.conclude!

      expect(ticket.reload.sprint_id).to eq(next_sprint.id)
      expect(next_sprint.reload).to be_active
    end

    it 'leaves tickets already in the final Estagio attached to the concluded sprint' do
      team = create(:team)
      sprint = create(:sprint, team: team)
      done_column = team.ticket_columns.find_by(kind: 'completed')
      ticket = create(:ticket, ticket_column: done_column, sprint: sprint)

      sprint.conclude!

      expect(ticket.reload.sprint_id).to eq(sprint.id)
    end

    it 'sends tickets back to the Backlog when there is no next sprint' do
      sprint = create(:sprint)
      ticket = create(:ticket, ticket_column: create(:ticket_column, team: sprint.team), sprint: sprint)

      sprint.conclude!

      expect(ticket.reload.sprint_id).to be_nil
    end

    it 'does nothing when called twice' do
      sprint = create(:sprint)
      sprint.conclude!
      expect { sprint.conclude! }.not_to raise_error
    end
  end
end
