FactoryBot.define do
  factory :chat_channel_member do
    chat_channel
    user

    after(:build) do |member|
      member.account ||= member.chat_channel&.account || create(:account)
    end
  end
end
