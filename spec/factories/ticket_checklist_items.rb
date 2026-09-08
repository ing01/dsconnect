FactoryBot.define do
  factory :ticket_checklist_item do
    sequence(:title) { |n| "Item #{n}" }
    ticket
    account { ticket&.account || create(:account) }
  end
end
