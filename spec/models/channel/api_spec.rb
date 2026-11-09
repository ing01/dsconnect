# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Api do
  # This validation happens in ApplicationRecord
  describe 'length validations' do
    let(:channel_api) { create(:channel_api) }

    context 'when webhook_url is a placeholder text' do
      it 'stores nothing for the text null' do
        channel_api.webhook_url = 'null'
        channel_api.valid?

        expect(channel_api.webhook_url).to be_nil
      end

      it 'stores nothing for blank and undefined' do
        ['', '  ', 'undefined'].each do |value|
          channel_api.webhook_url = value
          channel_api.valid?

          expect(channel_api.webhook_url).to be_nil
        end
      end

      it 'keeps a real url' do
        channel_api.webhook_url = 'https://example.com/hook'
        channel_api.valid?

        expect(channel_api.webhook_url).to eq('https://example.com/hook')
      end

      it 'never keeps a webhook on the client portal channel' do
        channel_api.additional_attributes = { Inboxes::EnsureClientPortalInboxService::MARKER_KEY => true }
        channel_api.webhook_url = 'https://example.com/hook'
        channel_api.valid?

        expect(channel_api.webhook_url).to be_nil
      end
    end

    context 'when it validates webhook_url length' do
      it 'valid when within limit' do
        channel_api.webhook_url = 'a' * Limits::URL_LENGTH_LIMIT
        expect(channel_api.valid?).to be true
      end

      it 'invalid when crossed the limit' do
        channel_api.webhook_url = 'a' * (Limits::URL_LENGTH_LIMIT + 1)
        channel_api.valid?
        expect(channel_api.errors[:webhook_url]).to include("is too long (maximum is #{Limits::URL_LENGTH_LIMIT} characters)")
      end
    end
  end
end
