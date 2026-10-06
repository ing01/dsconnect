require 'rails_helper'

# The point of sending synchronously: the caller has to know whether the message
# actually left, because closing the ticket depends on it. A record is never
# marked sent because a button was clicked.
RSpec.describe Tickets::CustomerCommunicationService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:company) { create(:company, account: account) }
  let(:contact) { create(:contact, account: account, company: company, email: 'renan@empresa.com') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }

  let(:ticket) do
    ticket = create(:ticket, account: account, ticket_column: column, team: team,
                             company: company, contact: contact)
    ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)
    ticket
  end

  # Two things stand between this spec and a delivered message, both of them
  # properties of the repo rather than of this code:
  #   - ApplicationMailer returns a NullMail unless SMTP is set or we are in
  #     development (`smtp_config_set_or_development?`);
  #   - config/initializers/mailer.rb forces `delivery_method = :sendmail`
  #     whenever SMTP_ADDRESS is blank, overriding the test environment.
  # Both are stated here so the examples do not depend on how the machine
  # running them happens to be configured.
  def with_smtp
    allow_any_instance_of(TicketCustomerMailer) # rubocop:disable RSpec/AnyInstance
      .to receive(:smtp_config_set_or_development?).and_return(true)
    previous = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    yield
  ensure
    ActionMailer::Base.delivery_method = previous
  end

  def perform(closing: true, notify_customer: nil)
    described_class.new(ticket: ticket, user: user, body: '<p>Resolvido</p>',
                        closing: closing, notify_customer: notify_customer).perform
  end

  describe 'when there is no SMTP configured' do
    # Stated rather than inherited from the machine: whether SMTP_ADDRESS
    # happens to be set in this environment must not decide what this example
    # exercises.
    before do
      allow_any_instance_of(TicketCustomerMailer) # rubocop:disable RSpec/AnyInstance
        .to receive(:smtp_config_set_or_development?).and_return(false)
    end

    # The mailer returns a NullMail; nothing left, so nothing may be reported as
    # sent - otherwise the ticket would become closable on a message that does
    # not exist.
    it 'refuses to report the message as sent' do
      expect { perform }.to raise_error(described_class::NotDelivered)

      communication = ticket.ticket_customer_communications.last
      expect(communication.status).to eq('failed')
      expect(ticket.reload.closing_communication_sent?).to be(false)
    end
  end

  describe 'when the delivery succeeds' do
    it 'records the message as sent, with when' do
      communication = with_smtp { perform }

      expect(communication.status).to eq('sent')
      expect(communication.sent_at).to be_present
      expect(communication.error_message).to be_nil
    end

    it 'sends to the requester address without being told it' do
      communication = with_smtp { perform }

      expect(communication.to_email).to eq('renan@empresa.com')
      expect(communication.contact).to eq(contact)
    end

    it 'actually enqueues a mail' do
      expect { with_smtp { perform } }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['renan@empresa.com'])
      expect(mail.subject).to eq(ticket.display_subject)
    end

    it 'records it in the ticket history' do
      with_smtp { perform }

      activity = ticket.ticket_activities.find_by(activity_type: :customer_communication_sent)
      expect(activity.user).to eq(user)
      expect(activity.new_value).to eq('renan@empresa.com')
    end

    # O ponto do pedido: o cliente precisa ser avisado (push) quando a equipe
    # responde de verdade - ver Client::TicketCommunicationPushNotificationJob.
    it 'enqueues a push notification job for the customer' do
      expect { with_smtp { perform } }.to have_enqueued_job(Client::TicketCommunicationPushNotificationJob)
    end

    it 'satisfies the closing requirement' do
      with_smtp { perform }

      expect(ticket.reload.closing_communication_sent?).to be(true)
    end

    # Ordinary correspondence is recorded but does not unlock the close.
    it 'does not satisfy it when the message is not a closing one' do
      with_smtp { perform(closing: false) }

      expect(ticket.reload.closing_communication_sent?).to be(false)
    end
  end

  # The customer should recognise the thread from the subject alone, so it is
  # the ticket header - and that holds for the closing notice too, which is
  # about the same ticket.
  describe 'the subject' do
    it 'carries the number, the Empresa, the Solicitante and the title' do
      communication = with_smtp { perform(closing: false) }

      expect(communication.subject).to eq(
        "##{ticket.display_id} - [#{company.name}] | [#{contact.name}] | [#{ticket.title}]"
      )
    end

    it 'is what the e-mail is actually titled with' do
      with_smtp { perform(closing: false) }

      expect(ActionMailer::Base.deliveries.last.subject).to eq(ticket.display_subject)
    end

    # The closing notice is a different message, but it titles itself the same
    # way: it is about the same ticket.
    it 'is the ticket header for the closing notice as well' do
      communication = with_smtp { perform(closing: true) }

      expect(communication.subject).to eq(ticket.display_subject)
    end

    it 'is what the closing e-mail is actually titled with' do
      with_smtp { perform(closing: true) }

      expect(ActionMailer::Base.deliveries.last.subject).to eq(ticket.display_subject)
    end
  end

  describe 'when the delivery fails' do
    before do
      allow(TicketCustomerMailer).to receive(:with).and_raise(Net::SMTPServerBusy, 'mailbox unavailable')
    end

    it 'raises rather than reporting success' do
      expect { perform }.to raise_error(Net::SMTPServerBusy)
    end

    it 'keeps the attempt with its reason' do
      expect { perform }.to raise_error(Net::SMTPServerBusy)

      communication = ticket.ticket_customer_communications.last
      expect(communication.status).to eq('failed')
      expect(communication.error_message).to include('mailbox unavailable')
      expect(communication.sent_at).to be_nil
    end

    # The rule that matters: a failed message must leave the ticket closable by
    # nobody.
    it 'leaves the ticket open and still blocked' do
      ticket.update!(service_catalog_item: create(:service_catalog_item))
      expect { perform }.to raise_error(Net::SMTPServerBusy)

      expect(ticket.reload.status).to eq('open')
      expect(ticket.closeable?).to be(false)
      expect { ticket.close! }.to raise_error(TicketClosing::NotAllowed)
    end

    it 'writes no history entry for a message that never left' do
      expect { perform }.to raise_error(Net::SMTPServerBusy)

      expect(ticket.ticket_activities.where(activity_type: :customer_communication_sent)).to be_empty
    end
  end

  # Registrar sem enviar e-mail. A mensagem existe para o cliente do mesmo jeito
  # - ela aparece na Area do Cliente -, e serve para quando a equipe ja falou com
  # ele por telefone ou WhatsApp e quer deixar isso no chamado.
  describe 'when the agent chooses not to e-mail the customer' do
    # O que este grupo protege acima de tudo: nao sai e-mail. O flag existe para
    # isso, e um envio indevido e exatamente o que ninguem descobriria olhando a
    # tela.
    it 'sends no mail at all' do
      expect { with_smtp { perform(notify_customer: false) } }
        .not_to(change { ActionMailer::Base.deliveries.count })
    end

    # `skipped`, nunca `sent`: `sent` afirma que o servidor de e-mail aceitou a
    # mensagem, e dizer isso de algo que nunca foi enviado tiraria do status a
    # unica coisa que ele afirma.
    it 'records it as registered without e-mail, not as sent' do
      communication = with_smtp { perform(notify_customer: false) }

      expect(communication.status).to eq('skipped')
      expect(communication.notify_customer).to be(false)
      expect(communication.sent_at).to be_present
      expect(communication.error_message).to be_nil
    end

    # O texto continua no chamado - e por isso que vale para o cliente.
    it 'keeps the message and its addressee' do
      communication = with_smtp { perform(notify_customer: false) }

      expect(communication.body).to eq('<p>Resolvido</p>')
      expect(communication.to_email).to eq('renan@empresa.com')
    end

    it 'satisfies the closing requirement' do
      with_smtp { perform(notify_customer: false) }

      expect(ticket.reload.closing_communication_sent?).to be(true)
    end

    # Fecha de verdade: sem isto o flag seria inutil no modal de fechamento.
    it 'lets the ticket be closed' do
      # A Categoria ja vem da fabrica (a Mesa provisiona a lista padrao); o
      # Catalogo e o que falta para o ticket poder fechar.
      ticket.update!(service_catalog_item: create(:service_catalog_item))
      with_smtp { perform(notify_customer: false) }

      expect(ticket.reload.closeable?).to be(true)
      expect { ticket.reload.close! }.not_to raise_error
    end

    it 'records it in the ticket history, saying no e-mail went out' do
      with_smtp { perform(notify_customer: false) }

      activity = ticket.ticket_activities.find_by(activity_type: :customer_communication_sent)
      expect(activity.user).to eq(user)
      expect(activity.meta['notify_customer']).to be(false)
    end

    # Mesma regra do e-mail: a pessoa marcou "nao notificar", nenhum canal
    # avisa o cliente - nem e-mail, nem push.
    it 'does not enqueue a push notification job for the customer' do
      expect { with_smtp { perform(notify_customer: false) } }
        .not_to have_enqueued_job(Client::TicketCommunicationPushNotificationJob)
    end

    # Sem SMTP nenhum o registro funciona igual: nao ha entrega para falhar. E o
    # caso de homologacao, onde antes o fechamento ficava travado.
    it 'works with no SMTP configured, because nothing is delivered' do
      allow_any_instance_of(TicketCustomerMailer) # rubocop:disable RSpec/AnyInstance
        .to receive(:smtp_config_set_or_development?).and_return(false)

      communication = perform(notify_customer: false)

      expect(communication.status).to eq('skipped')
    end
  end

  # Quem chama sem o campo continua enviando: a API e as telas antigas nao
  # conhecem o flag, e o silencio delas nao pode virar "nao envie".
  describe 'when nobody says anything about e-mail' do
    it 'sends, as it always did' do
      communication = with_smtp { perform }

      expect(communication.notify_customer).to be(true)
      expect(communication.status).to eq('sent')
      expect(ActionMailer::Base.deliveries.last.to).to eq(['renan@empresa.com'])
    end
  end
end
