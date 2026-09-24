FactoryBot.define do
  factory :automation_flow_run do
    account
    automation_rule
    conversation
    status { :running }
  end
end
