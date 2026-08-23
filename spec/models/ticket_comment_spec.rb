require 'rails_helper'

RSpec.describe TicketComment do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:content) }
  end

  describe 'account assignment' do
    it 'defaults account_id to the ticket account when not set' do
      ticket = create(:ticket)
      comment = described_class.new(ticket: ticket, user: create(:user, account: ticket.account), content: 'oi')

      comment.valid?

      expect(comment.account_id).to eq(ticket.account_id)
    end
  end

  describe 'activity logging' do
    it 'creates a comment_added ticket activity referencing the comment' do
      ticket = create(:ticket)
      user = create(:user, account: ticket.account)

      comment = create(:ticket_comment, ticket: ticket, user: user, content: 'Cliente confirmou o problema')

      activity = ticket.ticket_activities.find_by(activity_type: :comment_added)
      expect(activity).to be_present
      expect(activity.meta['ticket_comment_id']).to eq(comment.id)
      expect(activity.user).to eq(user)
    end
  end

  describe '#push_event_data' do
    it 'serializes with a nested user' do
      user = create(:user)
      comment = create(:ticket_comment, user: user, content: 'nota interna')

      data = comment.push_event_data
      expect(data[:content]).to eq('nota interna')
      expect(data[:user]).to eq({ id: user.id, name: user.name })
    end
  end
end
