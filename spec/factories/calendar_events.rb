FactoryBot.define do
  factory :calendar_event do
    account
    team { create(:team, account: account) }
    sequence(:title) { |n| "Evento #{n}" }
    start_at { 1.day.from_now.change(hour: 10, min: 0, sec: 0) }
    end_at { 1.day.from_now.change(hour: 11, min: 0, sec: 0) }
    recurrence_frequency { :single }

    trait :weekly do
      recurrence_frequency { :weekly }
      recurrence_interval { 1 }
    end

    trait :monthly do
      recurrence_frequency { :monthly }
      recurrence_interval { 1 }
    end
  end

  factory :calendar_event_occurrence_exception, class: 'CalendarEventOccurrenceException' do
    calendar_event
    account { calendar_event.account }
    occurrence_date { calendar_event.start_at.to_date + 7.days }
    kind { :cancelled }
  end
end
