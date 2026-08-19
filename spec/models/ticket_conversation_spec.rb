require 'rails_helper'

RSpec.describe TicketConversation do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:conversation) }
  end

  describe 'validations' do
    it 'does not allow linking the same conversation to the same ticket twice' do
      ticket = create(:ticket)
      conversation = create(:conversation, account: ticket.account)
      create(:ticket_conversation, ticket: ticket, conversation: conversation)

      duplicate = build(:ticket_conversation, ticket: ticket, conversation: conversation)

      expect(duplicate).not_to be_valid
    end
  end

  describe '#ensure_account_id' do
    it 'defaults to the ticket account when not provided' do
      ticket = create(:ticket)
      conversation = create(:conversation, account: ticket.account)

      ticket_conversation = TicketConversation.create!(ticket: ticket, conversation: conversation)

      expect(ticket_conversation.account_id).to eq(ticket.account_id)
    end
  end

  describe 'realtime updates' do
    it 'dispatches a conversation updated event on create and destroy' do
      ticket = create(:ticket)
      conversation = create(:conversation, account: ticket.account)

      expect_any_instance_of(Conversation).to receive(:dispatch_conversation_updated_event).twice # rubocop:disable RSpec/AnyInstance

      ticket_conversation = create(:ticket_conversation, ticket: ticket, conversation: conversation)
      ticket_conversation.destroy
    end
  end
end
