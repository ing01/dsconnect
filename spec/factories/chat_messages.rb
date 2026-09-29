FactoryBot.define do
  factory :chat_message do
    sequence(:content) { |n| "Mensagem #{n}" }
    chat_channel
    user

    after(:build) do |message|
      message.account ||= message.chat_channel&.account || create(:account)
    end
  end
end
