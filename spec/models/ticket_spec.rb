require 'rails_helper'

RSpec.describe Ticket do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket_column) }
    it { is_expected.to belong_to(:assignee).optional }
    it { is_expected.to belong_to(:team).optional }
    it { is_expected.to have_many(:ticket_conversations) }
    it { is_expected.to have_many(:conversations) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe 'priority enum' do
    it { is_expected.to define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2, urgent: 3) }
  end

  describe 'default position' do
    it 'assigns the next position within the column when not set' do
      column = create(:ticket_column)
      create(:ticket, ticket_column: column, position: 0)

      ticket = create(:ticket, ticket_column: column)

      expect(ticket.position).to eq(1)
    end
  end

  describe 'linking conversations' do
    it 'links multiple conversations to the same ticket' do
      ticket = create(:ticket)
      conversation_a = create(:conversation, account: ticket.account)
      conversation_b = create(:conversation, account: ticket.account)

      create(:ticket_conversation, ticket: ticket, conversation: conversation_a)
      create(:ticket_conversation, ticket: ticket, conversation: conversation_b)

      expect(ticket.conversations).to contain_exactly(conversation_a, conversation_b)
    end
  end

  describe '#push_event_data' do
    it 'includes the linked conversation ids' do
      ticket = create(:ticket, title: 'Bug no login')
      conversation = create(:conversation, account: ticket.account)
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      expect(ticket.push_event_data[:conversation_ids]).to eq([conversation.id])
    end
  end
end
