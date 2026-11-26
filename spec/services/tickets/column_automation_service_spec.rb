require 'rails_helper'

describe Tickets::ColumnAutomationService do
  describe '#perform with set_field' do
    let(:team) { create(:team, development_module_enabled: true) }
    let(:sprint) { create_sprint(team, 'Sprint 1') }
    let(:ticket) { create(:ticket, ticket_column: create(:ticket_column, team: team), sprint: sprint) }

    def create_sprint(owner, name)
      Sprint.create!(account: owner.account, team: owner, name: name, starts_on: Date.current, ends_on: 1.week.from_now)
    end

    def change(field, value)
      action = { 'type' => 'set_field', 'value' => { 'field' => field, 'value' => value } }
      column = create(:ticket_column, team: team, automations_enabled: true, automation_actions: [action])
      described_class.new(ticket: ticket, ticket_column: column).perform
      ticket.reload
    end

    it 'sends the ticket back to the Backlog when the Sprint value is empty' do
      expect(change('sprint', '').sprint_id).to be_nil
    end

    it 'moves the ticket to the chosen Sprint' do
      other = create_sprint(team, 'Sprint 2')

      expect(change('sprint', other.id.to_s).sprint_id).to eq(other.id)
    end

    it 'ignores a Sprint from another Mesa instead of clearing the field' do
      foreign = create_sprint(create(:team, account: team.account), 'Outra')

      expect(change('sprint', foreign.id.to_s).sprint_id).to eq(sprint.id)
    end

    it 'changes and clears other fields' do
      expect(change('priority', 'urgent').priority).to eq('urgent')
      expect(change('development_type', 'task').development_type).to eq('task')
      expect(change('category', '').ticket_category_id).to be_nil
    end

    it 'does nothing for an unknown field' do
      expect(change('title', '').title).to be_present
    end
  end

  describe '#perform with move_parent_to_column' do
    let(:team) { create(:team) }
    let(:origin_column) { create(:ticket_column, team: team) }
    let(:target_column) { create(:ticket_column, team: team) }

    it 'moves the parent ticket into the configured column' do
      parent = create(:ticket, ticket_column: origin_column)
      child = create(:ticket, ticket_column: origin_column, parent: parent)

      described_class.new(
        ticket: child,
        ticket_column: build(:ticket_column, team: team, automation_actions: [
                                { 'type' => 'move_parent_to_column', 'value' => { 'ticket_column_id' => target_column.id } }
                              ])
      ).perform

      expect(parent.reload.ticket_column).to eq(target_column)
    end

    it 'does nothing when the ticket has no parent' do
      child = create(:ticket, ticket_column: origin_column)

      expect do
        described_class.new(
          ticket: child,
          ticket_column: build(:ticket_column, team: team, automation_actions: [
                                  { 'type' => 'move_parent_to_column', 'value' => { 'ticket_column_id' => target_column.id } }
                                ])
        ).perform
      end.not_to raise_error
    end

    it 'does nothing when the configured column no longer exists' do
      parent = create(:ticket, ticket_column: origin_column)
      child = create(:ticket, ticket_column: origin_column, parent: parent)

      expect do
        described_class.new(
          ticket: child,
          ticket_column: build(:ticket_column, team: team, automation_actions: [
                                  { 'type' => 'move_parent_to_column', 'value' => { 'ticket_column_id' => 0 } }
                                ])
        ).perform
      end.not_to raise_error

      expect(parent.reload.ticket_column).to eq(origin_column)
    end

    it 'reports failures to the exception tracker instead of raising' do
      # `require_assignee` makes the parent's own `move_to!` reject the move
      # (Ticket#validate_target_column_rules!), since the parent has no assignee.
      strict_column = create(:ticket_column, team: team, require_assignee: true)
      parent = create(:ticket, ticket_column: origin_column, assignee: nil)
      child = create(:ticket, ticket_column: origin_column, parent: parent)

      expect(ChatwootExceptionTracker).to receive(:new).and_call_original

      described_class.new(
        ticket: child,
        ticket_column: build(:ticket_column, team: team, automation_actions: [
                                { 'type' => 'move_parent_to_column', 'value' => { 'ticket_column_id' => strict_column.id } }
                              ])
      ).perform

      expect(parent.reload.ticket_column).to eq(origin_column)
    end
  end
end
