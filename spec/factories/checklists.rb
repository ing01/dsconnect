FactoryBot.define do
  factory :checklist do
    sequence(:name) { |n| "Checklist #{n}" }
    items { [] }
    account
  end
end
