FactoryBot.define do
  factory :ticket_activity do
    ticket
    activity_type { 'status_changed' }

    after(:build) do |ticket_activity|
      ticket_activity.account ||= ticket_activity.ticket&.account || create(:account)
    end
  end
end
