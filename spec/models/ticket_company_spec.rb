require 'rails_helper'

RSpec.describe Ticket do
  let(:account) { create(:account) }
  let(:company) { create(:company, account: account) }
  let(:ticket_column) { create(:ticket_column, team: create(:team, account: account)) }

  describe 'company association' do
    it 'is optional' do
      ticket = build(:ticket, account: account, ticket_column: ticket_column, team: ticket_column.team, company: nil)

      expect(ticket).to be_valid
    end

    it 'links the ticket to a real Company' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, team: ticket_column.team, company: company)

      expect(ticket.reload.company).to eq(company)
      expect(company.reload.tickets).to include(ticket)
    end

    it 'refuses a Company from another account' do
      foreign = create(:company, account: create(:account))
      ticket = build(:ticket, account: account, ticket_column: ticket_column, team: ticket_column.team, company: foreign)

      expect(ticket).not_to be_valid
      expect(ticket.errors[:company]).to be_present
    end

    it 'survives the Company being deleted' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, team: ticket_column.team, company: company)

      company.destroy!

      expect(ticket.reload).to be_persisted
      expect(ticket.company_id).to be_nil
    end

    it 'carries the Empresa on the realtime payload' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, team: ticket_column.team, company: company)

      expect(ticket.push_event_data[:company_id]).to eq(company.id)
      expect(ticket.push_event_data[:company_name]).to eq(company.name)
    end
  end
end
