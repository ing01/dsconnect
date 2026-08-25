require 'rails_helper'

# The Solicitante is a person AT the Empresa, so the two cannot disagree.
# Enforced in the model, not only in the pickers - the API accepts both ids
# directly.
RSpec.describe Ticket do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:company) { create(:company, account: account) }
  let(:other_company) { create(:company, account: account) }
  let(:member) { create(:contact, account: account, company: company) }
  let(:outsider) { create(:contact, account: account, company: other_company) }

  def build_ticket(attributes = {})
    build(:ticket, { account: account, ticket_column: column, team: team }.merge(attributes))
  end

  describe 'Empresa and Solicitante' do
    it 'accepts a requester who belongs to the Empresa' do
      expect(build_ticket(company: company, contact: member)).to be_valid
    end

    it 'rejects a requester from another Empresa' do
      ticket = build_ticket(company: company, contact: outsider)

      expect(ticket).not_to be_valid
      expect(ticket.errors[:contact]).to be_present
    end

    it 'rejects a requester with no Empresa at all when the ticket has one' do
      loose = create(:contact, account: account, company: nil)

      expect(build_ticket(company: company, contact: loose)).not_to be_valid
    end

    # A ticket opened from a chat by somebody with no company still has a
    # requester, so the pair is only checked once the ticket has an Empresa.
    it 'accepts any requester while the ticket has no Empresa' do
      expect(build_ticket(company: nil, contact: outsider)).to be_valid
    end

    it 'accepts an Empresa with no requester' do
      expect(build_ticket(company: company, contact: nil)).to be_valid
    end

    describe 'changing the Empresa on a saved ticket' do
      let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team, company: company, contact: member) }

      it 'refuses to leave an incompatible pair behind' do
        expect(ticket.update(company: other_company)).to be(false)
        expect(ticket.reload.company).to eq(company)
      end

      it 'succeeds when the requester is cleared in the same save' do
        expect(ticket.update(company: other_company, contact: nil)).to be(true)
      end

      it 'succeeds when both move together' do
        replacement = create(:contact, account: account, company: other_company)

        expect(ticket.update(company: other_company, contact: replacement)).to be(true)
      end
    end
  end

  describe '.operational' do
    it 'keeps only the tickets still being worked on' do
      open_ticket = create(:ticket, account: account, ticket_column: column, team: team)
      %i[resolve! close! cancel!].each do |transition|
        create(:ticket, account: account, ticket_column: column, team: team).public_send(transition, nil)
      end

      expect(described_class.operational.pluck(:id)).to eq([open_ticket.id])
    end
  end
end
