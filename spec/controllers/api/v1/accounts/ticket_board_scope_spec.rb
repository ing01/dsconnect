require 'rails_helper'

# The Kanban is the operational board. Terminal tickets leave it but are never
# deleted, and the "Busca detalhada" must still find them.
RSpec.describe 'Kanban operational scope', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }

  def board_ticket_ids
    get "/api/v1/accounts/#{account.id}/teams/#{team.id}",
        headers: administrator.create_new_auth_token, as: :json
    response.parsed_body['ticket_columns'].flat_map { |c| c['tickets'] }.pluck('id')
  end

  def search_ticket_ids(params = {})
    get "/api/v1/accounts/#{account.id}/tickets",
        params: params, headers: administrator.create_new_auth_token, as: :json
    response.parsed_body['payload'].pluck('id')
  end

  def ticket_with(status)
    ticket = create(:ticket, account: account, ticket_column: column, team: team)
    case status
    when :resolved then ticket.resolve!(administrator)
    when :closed then ticket.close!(administrator)
    when :cancelled then ticket.cancel!(administrator)
    end
    ticket
  end

  describe 'the board' do
    it 'shows tickets that are still open' do
      open_ticket = ticket_with(:open)

      expect(board_ticket_ids).to include(open_ticket.id)
    end

    %i[resolved closed cancelled].each do |status|
      it "hides #{status} tickets" do
        terminal = ticket_with(status)

        expect(board_ticket_ids).not_to include(terminal.id)
      end
    end

    it 'brings a reopened ticket back' do
      ticket = ticket_with(:closed)
      expect(board_ticket_ids).not_to include(ticket.id)

      ticket.reopen!(administrator)

      expect(board_ticket_ids).to include(ticket.id)
    end
  end

  describe 'the tickets themselves' do
    it 'are not deleted' do
      %i[resolved closed cancelled].each { |status| ticket_with(status) }

      expect(Ticket.count).to eq(3)
    end

    # Positions and re-indexing must keep seeing every ticket in the column,
    # otherwise a closed ticket's slot would be handed out twice.
    it 'still occupy their slot in the column' do
      first = ticket_with(:open)
      closed = ticket_with(:closed)
      last = ticket_with(:open)

      expect(column.reload.tickets.pluck(:id)).to eq([first.id, closed.id, last.id])
    end
  end

  # The "Busca detalhada" deliberately does not apply the scope.
  describe 'the detailed search' do
    it 'returns terminal tickets alongside open ones' do
      all = %i[open resolved closed cancelled].map { |status| ticket_with(status) }

      expect(search_ticket_ids).to match_array(all.map(&:id))
    end

    %i[resolved closed cancelled].each do |status|
      it "finds #{status} tickets when filtering by that status" do
        terminal = ticket_with(status)
        ticket_with(:open)

        expect(search_ticket_ids({ status: status })).to eq([terminal.id])
      end
    end

    it 'finds a terminal ticket by its Estagio' do
      closed = ticket_with(:closed)

      expect(search_ticket_ids({ ticket_column_id: column.id })).to include(closed.id)
    end
  end
end
