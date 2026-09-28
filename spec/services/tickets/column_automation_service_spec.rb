require 'rails_helper'

describe Tickets::ColumnAutomationService do
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
