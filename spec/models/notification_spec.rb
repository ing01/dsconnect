# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification do
  include ActiveJob::TestHelper

  context 'with associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:user) }
  end

  context 'with default order by' do
    it 'sort by primary id desc' do
      notification1 = create(:notification)
      create(:notification)
      notification3 = create(:notification)

      expect(described_class.all.first.id).to eq notification1.id
      expect(described_class.all.last.id).to eq notification3.id
    end
  end

  context 'when push_title is called' do
    it 'returns appropriate title suited for the notification type conversation_creation' do
      notification = create(:notification, notification_type: 'conversation_creation')
      contact_name = notification.conversation.contact.name
      display_id = notification.primary_actor.display_id
      inbox_name = notification.primary_actor.inbox.name
      expect(notification.push_message_title).to eq "#{contact_name} started conversation (##{display_id}) in #{inbox_name}"
    end

    it 'returns appropriate title suited for the notification type conversation_assignment' do
      notification = create(:notification, notification_type: 'conversation_assignment')
      contact_name = notification.conversation.contact.name
      display_id = notification.primary_actor.display_id
      expect(notification.push_message_title).to eq "#{contact_name}'s conversation (##{display_id}) has been assigned to you"
    end

    it 'returns appropriate title suited for the notification type assigned_conversation_new_message' do
      message = create(:message, sender: create(:user), content: Faker::Lorem.paragraphs(number: 2))
      notification = create(:notification, notification_type: 'assigned_conversation_new_message', primary_actor: message.conversation,
                                           secondary_actor: message)

      contact_name = notification.conversation.contact.name
      expect(notification.push_message_title).to eq "New message from #{contact_name} (##{notification.primary_actor.display_id})"
    end

    it 'returns appropriate title suited for the notification type assigned_conversation_new_message when attachment message' do
      # checking content nil should be suffice for attachments
      message = create(:message, sender: create(:user), content: nil)
      notification = create(:notification, notification_type: 'assigned_conversation_new_message', primary_actor: message.conversation,
                                           secondary_actor: message)

      contact_name = notification.conversation.contact.name
      expect(notification.push_message_title).to eq "New message from #{contact_name} (##{notification.primary_actor.display_id})"
    end

    it 'returns appropriate title suited for the notification type participating_conversation_new_message' do
      message = create(:message, sender: create(:user), content: Faker::Lorem.paragraphs(number: 2))
      notification = create(:notification, notification_type: 'participating_conversation_new_message', primary_actor: message.conversation,
                                           secondary_actor: message)

      contact_name = notification.conversation.contact.name
      expect(notification.push_message_title).to eq "New message from #{contact_name} (##{notification.primary_actor.display_id})"
    end

    it 'returns appropriate title suited for the notification type conversation_mention' do
      message = create(:message, sender: create(:user), content: 'Hey [@John](mention://user/1/john), can you check this ticket?')
      notification = create(:notification, notification_type: 'conversation_mention', primary_actor: message.conversation,
                                           secondary_actor: message)

      contact_name = notification.conversation.contact.name
      display_id = notification.primary_actor.display_id
      expect(notification.push_message_title).to eq "You have been mentioned in #{contact_name}'s conversation (##{display_id})"
    end

    it 'renders the title in the account locale, whatever the thread locale happens to be' do
      notification = create(:notification, notification_type: 'conversation_assignment')
      notification.account.update!(locale: 'pt_BR')

      titulo_en = I18n.with_locale(:en) { notification.reload.push_message_title }
      titulo_pt = I18n.with_locale(:pt_BR) { notification.reload.push_message_title }

      expect(titulo_en).to eq titulo_pt
    end
  end

  context 'when push_message_body is called' do
    it 'returns appropriate body suited for the notification type conversation_creation' do
      conversation = create(:conversation)
      message = create(:message, sender: create(:user), content: Faker::Lorem.paragraphs(number: 2), conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_creation', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: #{message.content.truncate_words(10)}"
    end

    it 'returns appropriate body suited for the notification type conversation_assignment' do
      conversation = create(:conversation)
      message = create(:message, sender: create(:user), content: Faker::Lorem.paragraphs(number: 2), conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_assignment', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: #{message.content.truncate_words(10)}"
    end

    it 'returns appropriate body suited for the notification type conversation_assignment with outgoing message only' do
      conversation = create(:conversation)
      message = create(:message, sender: create(:user), content: Faker::Lorem.paragraphs(number: 2), message_type: :outgoing,
                                 conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_assignment', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: #{message.content.truncate_words(10)}"
    end

    it 'returns appropriate body suited for the notification type assigned_conversation_new_message' do
      conversation = create(:conversation)
      message = create(:message, sender: create(:user), content: Faker::Lorem.paragraphs(number: 2), conversation: conversation)
      notification = create(:notification, notification_type: 'assigned_conversation_new_message', primary_actor: conversation,
                                           secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: #{message.content.truncate_words(10)}"
    end

    it 'returns appropriate body suited for the notification type assigned_conversation_new_message when attachment message' do
      conversation = create(:conversation)
      message = create(:message, sender: create(:user), content: nil, conversation: conversation)
      attachment = message.attachments.new(file_type: :image, account_id: message.account_id)
      attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      message.save!
      notification = create(:notification, notification_type: 'assigned_conversation_new_message', primary_actor: conversation,
                                           secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: Attachment"
    end

    it 'returns appropriate body suited for the notification type participating_conversation_new_message having multple mention' do
      conversation = create(:conversation)
      message = create(:message, sender: create(:user),
                                 content: 'Hey [@John](mention://user/1/john), [@Alisha Peter](mention://user/2/alisha) can you check this ticket?',
                                 conversation: conversation)
      notification = create(:notification, notification_type: 'participating_conversation_new_message', primary_actor: conversation,
                                           secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: Hey @John, @Alisha Peter can you check this ticket?"
    end

    it 'returns appropriate body suited for the notification type conversation_mention if username contains white space' do
      conversation = create(:conversation)
      message = create(:message, sender: create(:user), content: 'Hey [@John Peter](mention://user/1/john%20K) please check this?',
                                 conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_mention', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: Hey @John Peter please check this?"
    end

    it 'returns appropriate body suited for the notification type conversation_mention if username contains emoji' do
      conversation = create(:conversation)
      content = 'Hey [@👍 customer support](mention://team/1/%F0%9F%91%8D%20customer%20support) please check this?'
      message = create(:message, sender: create(:user), content: content, conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_mention', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: Hey @👍 customer support please check this?"
    end

    it 'returns appropriate body suited for the notification type conversation_mention if team name contains emoji and spaces' do
      conversation = create(:conversation)
      content = 'Please check [@🚀 Development Team](mention://team/2/%F0%9F%9A%80%20Development%20Team)'
      message = create(:message, sender: create(:user), content: content, conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_mention', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: Please check @🚀 Development Team"
    end

    it 'returns appropriate body suited for the notification type conversation_mention with mixed emoji and regular mentions' do
      conversation = create(:conversation)
      content = 'Hey [@John Doe](mention://user/1/John%20Doe) and ' \
                '[@👍 customer support](mention://team/1/%F0%9F%91%8D%20customer%20support) please review'
      message = create(:message, sender: create(:user), content: content, conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_mention', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: Hey @John Doe and @👍 customer support please review"
    end

    it 'returns appropriate body suited for the notification type conversation_mention with special characters in names' do
      conversation = create(:conversation)
      content = 'Please review [@user@domain.com](mention://user/4/user%40domain.com)'
      message = create(:message, sender: create(:user), content: content, conversation: conversation)
      notification = create(:notification, notification_type: 'conversation_mention', primary_actor: conversation, secondary_actor: message)
      expect(notification.push_message_body).to eq "#{message.sender.name}: Please review @user@domain.com"
    end

    it 'calls remove duplicate notification job' do
      allow(Notification::RemoveDuplicateNotificationJob).to receive(:perform_later)
      notification = create(:notification, notification_type: 'conversation_mention')
      expect(Notification::RemoveDuplicateNotificationJob).to have_received(:perform_later).with(notification)
    end
  end

  context 'when notification_type is ticket_customer_communication_received' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:column) { create(:ticket_column, team: team) }
    let(:company) { create(:company, account: account) }
    let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team, company: company) }
    let(:communication) { create(:ticket_customer_communication, ticket: ticket, direction: 'inbound') }
    let(:notification) do
      create(:notification, notification_type: 'ticket_customer_communication_received', account: account,
                            primary_actor: ticket, secondary_actor: communication)
    end

    it 'leva pro proprio ticket, na aba de comunicacao - nao pra triagem' do
      expect(notification.push_target_path).to eq("/app/accounts/#{account.id}/tickets/#{ticket.id}?tab=communication")
    end

    it 'agrupa pelo ticket, nao pela tela de triagem' do
      expect(notification.push_group_tag).to eq("ticket_communication_#{ticket.id}")
    end

    it 'o titulo cita o numero do chamado' do
      expect(notification.push_message_title).to include("##{ticket.display_id}")
    end

    it 'o corpo usa quem escreveu e o texto da comunicacao' do
      expect(notification.push_message_body).to eq("#{communication.author_name}: #{communication.body.truncate_words(10)}")
    end

    it 'nao quebra ao montar o push_event_data (secondary_actor precisa responder push_event_data)' do
      expect { notification.push_event_data }.not_to raise_error
    end
  end

  context 'when notification_type is ticket_triage_pending (still routes to triage)' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:column) { create(:ticket_column, team: team) }
    let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team) }
    let(:notification) do
      create(:notification, notification_type: 'ticket_triage_pending', account: account, primary_actor: ticket)
    end

    it 'leva pra fila de triagem, nao pro ticket' do
      expect(notification.push_target_path).to eq("/app/accounts/#{account.id}/tickets/triage")
    end

    it 'agrupa pela tela, nao pelo ticket' do
      expect(notification.push_group_tag).to eq('ticket_triage')
    end
  end

  context 'when fcm push data' do
    it 'returns correct data for primary actor conversation' do
      notification = create(:notification, notification_type: 'conversation_creation')
      expect(notification.fcm_push_data[:primary_actor]).to eq({
                                                                 'id' => notification.primary_actor.display_id
                                                               })
    end

    it 'returns correct data for primary actor message' do
      message = create(:message, sender: create(:user), content: Faker::Lorem.paragraphs(number: 2))
      notification = create(:notification, notification_type: 'assigned_conversation_new_message', primary_actor: message.conversation,
                                           secondary_actor: message)
      expect(notification.fcm_push_data[:primary_actor]).to eq({
                                                                 'id' => notification.primary_actor.display_id
                                                               })
    end

    it 'includes the account id so the mobile app can open the conversation in the right account' do
      notification = create(:notification, notification_type: 'conversation_creation')
      expect(notification.fcm_push_data[:account_id]).to eq(notification.account_id)
    end
  end

  context 'when primary actor is deleted' do
    let!(:conversation) { create(:conversation) }

    it 'clears notifications' do
      notification = create(:notification, notification_type: 'conversation_creation', primary_actor: conversation)
      perform_enqueued_jobs do
        conversation.inbox.destroy!
      end

      expect { notification.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
