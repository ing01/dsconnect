FactoryBot.define do
  factory :ticket_customer_communication do
    ticket
    user
    to_email { 'cliente@empresa.com' }
    subject { 'Encerramento do ticket' }
    body { '<p>Atendimento concluído.</p>' }
    status { 'pending' }

    after(:build) do |communication|
      communication.account ||= communication.ticket&.account
    end
  end
end
