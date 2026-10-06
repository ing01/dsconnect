require 'rails_helper'

RSpec.describe Client::TicketCommunicationPushNotificationService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:company) { create(:company, account: account) }
  let(:contact) { create(:contact, account: account, company: company) }
  let(:ticket) do
    create(:ticket, account: account, ticket_column: column, team: team, company: company, contact: contact)
  end
  let(:communication) do
    create(:ticket_customer_communication, ticket: ticket, direction: 'outbound', contact: contact)
  end

  def perform(comm = communication)
    described_class.new(communication: comm).perform
  end

  def create_subscription!(for_contact = contact)
    ClientPushSubscription.create!(
      account: account, contact: for_contact,
      subscription_attributes: { 'endpoint' => 'https://push.example/x', 'p256dh' => 'p', 'auth' => 'a' }
    )
  end

  before do
    allow(VapidService).to receive(:public_key).and_return('chave-publica')
    allow(VapidService).to receive(:private_key).and_return('chave-privada')
  end

  it 'nao faz nada sem VAPID configurado' do
    allow(VapidService).to receive(:public_key).and_return(nil)
    create_subscription!

    expect(WebPush).not_to receive(:payload_send)
    perform
  end

  it 'cai no solicitante do ticket quando a comunicacao nao tem contato gravado' do
    create_subscription!
    communication.update!(contact: nil)

    expect(WebPush).to receive(:payload_send)

    perform
  end

  it 'nao faz nada quando nem a comunicacao nem o ticket tem contato' do
    ticket_sem_contato = create(:ticket, account: account, ticket_column: column, team: team)
    comunicacao_sem_contato = create(:ticket_customer_communication, ticket: ticket_sem_contato, direction: 'outbound',
                                                                     contact: nil)

    expect(WebPush).not_to receive(:payload_send)

    perform(comunicacao_sem_contato)
  end

  it 'envia o push para cada assinatura do contato' do
    create_subscription!
    create_subscription!

    expect(WebPush).to receive(:payload_send).twice

    perform
  end

  it 'manda o numero do chamado no titulo e o corpo da mensagem' do
    create_subscription!
    enviado = nil
    allow(WebPush).to receive(:payload_send) { |args| enviado = JSON.parse(args[:message]) }

    perform

    expect(enviado['title']).to include("##{ticket.display_id}")
    expect(enviado['body']).to eq(communication.body)
    expect(enviado['url']).to eq("/app/client/tickets/#{ticket.id}")
  end

  it 'destroi a assinatura quando o navegador recusa como expirada' do
    subscription = create_subscription!
    allow(WebPush).to receive(:payload_send)
      .and_raise(WebPush::ExpiredSubscription.new(double(body: 'expirada'), 'push.example')) # rubocop:disable RSpec/VerifiedDoubles

    perform

    expect(ClientPushSubscription.exists?(subscription.id)).to be(false)
  end
end
