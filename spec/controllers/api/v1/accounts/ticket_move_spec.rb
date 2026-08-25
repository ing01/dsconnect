require 'rails_helper'

RSpec.describe 'Ticket move positioning', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:origin) { create(:ticket_column, team: team) }
  let(:destination) { create(:ticket_column, team: team) }

  def move(ticket, params)
    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/move",
          params: params,
          headers: administrator.create_new_auth_token,
          as: :json
  end

  def display_ids_of(column)
    column.tickets.order(:position, :id).pluck(:display_id)
  end

  it 'stores the position drag-and-drop sent' do
    moving = create(:ticket, account: account, ticket_column: origin, team: team)

    move(moving, { ticket_column_id: destination.id, position: 0 })

    expect(moving.reload.ticket_column).to eq(destination)
    expect(moving.position).to eq(0)
  end

  # The detail page's Estagio select omits `position` on purpose. Creation order
  # sets display_id, so building them in sequence gives `moving` a number that
  # falls between the two already sitting in the destination.
  it 'slots the ticket in by ticket number when no position is sent' do
    first = create(:ticket, account: account, ticket_column: destination, team: team)
    moving = create(:ticket, account: account, ticket_column: origin, team: team)
    third = create(:ticket, account: account, ticket_column: destination, team: team)

    move(moving, { ticket_column_id: destination.id })

    expect(display_ids_of(destination.reload)).to eq(
      [first.display_id, moving.display_id, third.display_id]
    )
  end

  it 'puts the lowest number first' do
    moving = create(:ticket, account: account, ticket_column: origin, team: team)
    create(:ticket, account: account, ticket_column: destination, team: team)

    move(moving, { ticket_column_id: destination.id })

    expect(destination.reload.tickets.order(:position).first).to eq(moving)
  end

  it 'puts the highest number last' do
    create(:ticket, account: account, ticket_column: destination, team: team)
    moving = create(:ticket, account: account, ticket_column: origin, team: team)

    move(moving, { ticket_column_id: destination.id })

    expect(destination.reload.tickets.order(:position).last).to eq(moving)
  end
end
