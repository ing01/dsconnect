require 'rails_helper'

RSpec.describe Projects::CreateScheduleService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:project) { create(:project, account: account, team: team) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:start_at) { 2.days.from_now.change(hour: 9) }

  def perform(items)
    described_class.new(account: account, project: project, user: user, items: items).perform
  end

  context 'with a new ticket' do
    it 'creates the ticket with the description and schedules it' do
      results = perform([{ new_ticket_title: '1. Levantamento de Requisito',
                           description: 'Levantar os requisitos com o cliente',
                           start_at: start_at.iso8601 }])

      expect(results.first.success).to be(true)
      ticket = results.first.ticket
      expect(ticket.description).to eq('Levantar os requisitos com o cliente')
      expect(ticket.project).to eq(project)
      expect(results.first.calendar_event).to be_present
    end

    it 'reports the failure of the row when the description is missing' do
      results = perform([{ new_ticket_title: '1. Levantamento de Requisito', start_at: start_at.iso8601 }])

      expect(results.first.success).to be(false)
      expect(account.tickets.where(title: '1. Levantamento de Requisito')).to be_empty
    end
  end
end
