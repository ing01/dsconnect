FactoryBot.define do
  factory :ticket_attachment do
    account { ticket&.account || create(:account) }
    ticket
    user { nil }

    after(:build) do |attachment|
      attachment.file.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )
    end
  end
end
