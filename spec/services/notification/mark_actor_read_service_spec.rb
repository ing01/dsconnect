require 'rails_helper'

# Ver o assunto por outro caminho (abrir o ticket pela lista, por exemplo) tira a
# notificacao dele da caixa de entrada.
describe Notification::MarkActorReadService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, account: account, team: team, ticket_column: column) }
  let(:other_ticket) { create(:ticket, account: account, team: team, ticket_column: column) }

  def notify(actor, to: user)
    create(:notification, account: account, user: to, notification_type: 'ticket_customer_communication_received',
                          primary_actor: actor)
  end

  it 'marks every unread notification of the actor as read' do
    first = notify(ticket)
    second = notify(ticket)

    described_class.new(user: user, account: account, primary_actor: ticket).perform

    expect(first.reload.read_at).to be_present
    expect(second.reload.read_at).to be_present
  end

  it 'leaves other actors and other users alone' do
    elsewhere = notify(other_ticket)
    theirs = notify(ticket, to: create(:user, account: account))

    described_class.new(user: user, account: account, primary_actor: ticket).perform

    expect(elsewhere.reload.read_at).to be_nil
    expect(theirs.reload.read_at).to be_nil
  end
end
