# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountUser do
  include ActiveJob::TestHelper

  let!(:account_user) { create(:account_user) }
  let!(:inbox) { create(:inbox, account: account_user.account) }

  describe 'notification_settings' do
    it 'gets created with the right default settings' do
      expect(account_user.user.notification_settings).not_to be_nil

      expect(account_user.user.notification_settings.first.email_conversation_creation?).to be(false)
      expect(account_user.user.notification_settings.first.email_conversation_assignment?).to be(true)
    end

    # Avaliado pelo responsavel/seguidores de um ticket - ver
    # Tickets::CustomerCommunicationNotificationBuilder. Nasce ligado para
    # agente novo pelo mesmo motivo do Chat Interno: sem isto, ninguem saberia
    # que a opcao existe.
    it 'nasce com o push de resposta do cliente no ticket ligado' do
      expect(account_user.user.notification_settings.first.push_ticket_customer_communication_received?).to be(true)
    end
  end

  describe 'horario de almoco' do
    # 11:00 as 13:00 em America/Sao_Paulo (UTC-3) - usado nos horarios abaixo.
    def at_sao_paulo(hour, min)
      Time.find_zone!('America/Sao_Paulo').local(2026, 10, 15, hour, min)
    end

    describe 'validations' do
      it 'is valid without any lunch field set' do
        expect(build(:account_user)).to be_valid
      end

      it 'is invalid when only some of the 4 fields are set' do
        account_user.lunch_start_hour = 11

        expect(account_user).not_to be_valid
        expect(account_user.errors[:base]).to be_present
      end

      it 'is invalid when the lunch break end is not after the start' do
        account_user.assign_attributes(lunch_start_hour: 13, lunch_start_minutes: 0,
                                       lunch_end_hour: 11, lunch_end_minutes: 0)

        expect(account_user).not_to be_valid
      end

      it 'is valid with all 4 fields set and end after start' do
        account_user.assign_attributes(lunch_start_hour: 11, lunch_start_minutes: 0,
                                       lunch_end_hour: 13, lunch_end_minutes: 0)

        expect(account_user).to be_valid
      end
    end

    describe '#lunch_blackout_now?' do
      before do
        account_user.update!(lunch_start_hour: 11, lunch_start_minutes: 0,
                             lunch_end_hour: 13, lunch_end_minutes: 0)
      end

      it 'is false without a lunch break configured' do
        account_user.assign_attributes(lunch_start_hour: nil, lunch_start_minutes: nil,
                                       lunch_end_hour: nil, lunch_end_minutes: nil)

        expect(account_user.lunch_blackout_now?(at: at_sao_paulo(11, 0))).to be(false)
      end

      it 'is false well before the 20-minute buffer' do
        expect(account_user.lunch_blackout_now?(at: at_sao_paulo(10, 30))).to be(false)
      end

      it 'is true exactly 20 minutes before the start' do
        expect(account_user.lunch_blackout_now?(at: at_sao_paulo(10, 40))).to be(true)
      end

      it 'is true during the lunch break' do
        expect(account_user.lunch_blackout_now?(at: at_sao_paulo(12, 0))).to be(true)
      end

      it 'is false right after the lunch break ends' do
        expect(account_user.lunch_blackout_now?(at: at_sao_paulo(13, 1))).to be(false)
      end
    end

    describe '.lunch_blackout_user_ids' do
      it 'only includes agents currently inside their own blackout window' do
        on_lunch = create(:account_user, account: account_user.account,
                                         lunch_start_hour: 11, lunch_start_minutes: 0,
                                         lunch_end_hour: 13, lunch_end_minutes: 0)
        not_on_lunch_yet = create(:account_user, account: account_user.account,
                                                 lunch_start_hour: 13, lunch_start_minutes: 0,
                                                 lunch_end_hour: 15, lunch_end_minutes: 0)

        travel_to(at_sao_paulo(12, 0)) do
          ids = described_class.lunch_blackout_user_ids(account_user.account_id)

          expect(ids).to include(on_lunch.user_id)
          expect(ids).not_to include(not_on_lunch_yet.user_id, account_user.user_id)
        end
      end
    end
  end

  describe 'permissions' do
    it 'returns the right permissions' do
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'returns the right permissions for administrator' do
      account_user.administrator!
      expect(account_user.permissions).to eq(['administrator'])
    end
  end

  describe 'destroy call agent::destroy service' do
    it 'gets created with the right default settings' do
      create(:conversation, account: account_user.account, assignee: account_user.user, inbox: inbox)
      user = account_user.user

      expect(user.assigned_conversations.count).to eq(1)

      perform_enqueued_jobs do
        account_user.destroy!
      end

      expect(user.assigned_conversations.count).to eq(0)
    end
  end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:user) { create(:user) }
    let(:invalidator) { instance_double(Conversations::UnreadCounts::FilteredCountInvalidator, user_visibility_changed!: true) }

    before do
      allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).and_return(invalidator)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'invalidates filtered counts when the user is added to an account' do
      create(:account_user, account: account, user: user)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id)
    end

    it 'invalidates filtered counts when the user role changes' do
      account_user = create(:account_user, account: account, user: user)

      account_user.update!(role: :administrator)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
    end

    it 'invalidates filtered counts when the user is removed from an account' do
      account_user = create(:account_user, account: account, user: user)

      account_user.destroy!

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
    end
  end
end
