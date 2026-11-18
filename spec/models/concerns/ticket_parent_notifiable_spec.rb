require 'rails_helper'

RSpec.describe TicketParentNotifiable do
  let(:account) { create(:account) }
  let(:dev_team) { create(:team, account: account, development_module_enabled: true) }
  let(:other_team) { create(:team, account: account, development_module_enabled: false) }
  let(:parent) { create(:ticket, account: account, ticket_column: create(:ticket_column, team: other_team), team: other_team) }

  def child_in(team)
    create(:ticket, account: account, ticket_column: create(:ticket_column, team: team), team: team, parent: parent)
  end

  def close(ticket)
    ticket.update!(status: :closed, closed_at: Time.zone.now)
  end

  it 'enqueues the parent notice when a child of a development Mesa is closed' do
    child = child_in(dev_team)

    expect { close(child) }.to have_enqueued_job(Tickets::ChildCompletedJob).with(child.id)
  end

  it 'still enqueues it when the ticket is reloaded in the same transaction' do
    child = child_in(dev_team)

    expect do
      ActiveRecord::Base.transaction do
        close(child)
        # O reload apaga o registro do que mudou; o aviso nao pode depender dele.
        child.reload
      end
    end.to have_enqueued_job(Tickets::ChildCompletedJob).with(child.id)
  end

  it 'does not enqueue for a Mesa without the development module' do
    expect { close(child_in(other_team)) }.not_to have_enqueued_job(Tickets::ChildCompletedJob)
  end

  it 'does not enqueue for a ticket without a parent' do
    ticket = create(:ticket, account: account, ticket_column: create(:ticket_column, team: dev_team), team: dev_team)

    expect { close(ticket) }.not_to have_enqueued_job(Tickets::ChildCompletedJob)
  end

  it 'does not enqueue when a closed child is reopened' do
    child = child_in(dev_team)
    close(child)

    expect { child.reopen!(nil) }.not_to have_enqueued_job(Tickets::ChildCompletedJob)
  end
end
