FactoryBot.define do
  factory :ticket_attachment do
    account { ticket&.account || create(:account) }
    ticket
    user { nil }
    transient do
      filename { 'avatar.png' }
    end

    after(:build) do |attachment, evaluator|
      attachment.file.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: evaluator.filename,
        content_type: 'image/png'
      )
    end
  end
end
