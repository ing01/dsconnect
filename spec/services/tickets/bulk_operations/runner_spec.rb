require 'rails_helper'

# Basico: a operacao roda, grava o resultado por ticket e o desfazer volta o campo.
# Permissao e e-mail ficam de fora de proposito.
RSpec.describe Tickets::BulkOperations::Runner do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:column) { create(:ticket_column, team: create(:team, account: account)) }
  let!(:tickets) { create_list(:ticket, 2, ticket_column: column, priority: 'low') }

  def run_operation(action, params, items)
    operation = account.ticket_bulk_operations.create!(user: admin, action: action, params: params, total: items.size)
    items.each { |ticket| operation.items.create!(ticket_id: ticket.id, display_id: ticket.display_id) }
    described_class.new(operation: operation).perform
    operation.reload
  end

  it 'changes the priority of every ticket and records the outcome' do
    operation = run_operation('priority', { 'priority' => 'urgent' }, tickets)

    expect(operation).to be_completed
    expect(operation.succeeded).to eq(2)
    expect(tickets.map { |ticket| ticket.reload.priority }).to all(eq('urgent'))
  end

  it 'skips tickets that already have the value' do
    operation = run_operation('priority', { 'priority' => 'low' }, tickets)

    expect(operation.skipped).to eq(2)
  end

  it 'undoes a field change' do
    original = run_operation('priority', { 'priority' => 'urgent' }, tickets)
    expect(original).to be_undoable

    undo = account.ticket_bulk_operations.create!(
      user: admin, action: 'priority', params: { 'original_action' => 'priority' }, undo_of_id: original.id, total: 2
    )
    original.items.succeeded.each { |item| undo.items.create!(ticket_id: item.ticket_id, display_id: item.display_id, before: item.before) }
    described_class.new(operation: undo).perform

    expect(tickets.map { |ticket| ticket.reload.priority }).to all(eq('low'))
  end
end
