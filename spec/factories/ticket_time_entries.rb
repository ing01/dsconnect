FactoryBot.define do
  factory :ticket_time_entry do
    ticket
    account { ticket&.account || create(:account) }
    user { create(:user, account: account) }
    category { 'implantacao' }
    hours { 1 }
    worked_on { Time.zone.today }
  end
end
