require 'rails_helper'

# The customer-facing message. Every value is read from the Ticket, its Contact
# and its Company - nothing is stored a second time to compose the e-mail.
RSpec.describe TicketCustomerMailer do
  # ApplicationMailer takes the locale from the account, so this is what decides
  # the wording the customer receives.
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:user) { create(:user, account: account, name: 'Maria Suporte') }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:company) { create(:company, account: account, name: 'ELETROSUL - FILIAL') }
  let(:contact) do
    create(:contact, account: account, company: company,
                     name: 'João Vitor', email: 'joao@eletrosul.com')
  end

  let(:ticket) do
    create(:ticket, account: account, ticket_column: column, team: team,
                    company: company, contact: contact, title: 'Erro na emissão da nota')
  end

  let(:communication) do
    ticket.ticket_customer_communications.create!(
      account_id: account.id, user: user, contact: contact,
      to_email: contact.email, subject: 'Sobre o seu chamado',
      body: '<p>Realizamos os ajustes necessários.</p>',
      closing: false, status: 'sent', sent_at: Time.zone.parse('2026-08-26 11:01')
    )
  end

  # ApplicationMailer returns a NullMail unless SMTP is set or we are in
  # development, so the condition is stated rather than inherited from the
  # machine running the suite.
  before do
    allow_any_instance_of(described_class) # rubocop:disable RSpec/AnyInstance
      .to receive(:smtp_config_set_or_development?).and_return(true)
  end

  def body_of(mail)
    mail.body.encoded
  end

  describe '#customer_message' do
    subject(:mail) { described_class.with(account: account).customer_message(communication) }

    it 'goes to the requester address with the agent subject' do
      expect(mail.to).to eq(['joao@eletrosul.com'])
      expect(mail.subject).to eq('Sobre o seu chamado')
    end

    it 'greets the contact by name and names the Empresa' do
      expect(body_of(mail)).to include('Olá João Vitor, da empresa ELETROSUL - FILIAL.')
    end

    # The same shape the ticket page header shows.
    it 'identifies the ticket by number, Empresa, Solicitante and title' do
      expect(body_of(mail)).to include(
        "##{ticket.display_id} - [ELETROSUL - FILIAL] | [João Vitor] | [Erro na emissão da nota]"
      )
    end

    it 'carries the message the agent wrote' do
      expect(body_of(mail)).to include('Realizamos os ajustes necessários.')
    end

    it 'stamps the moment it was sent' do
      expect(body_of(mail)).to include('26/08/2026 11:01')
    end

    it 'signs off for the company' do
      expect(body_of(mail)).to include('Atenciosamente,')
      expect(body_of(mail)).to include('Duesoft Sistemas')
    end

    describe 'the account timezone' do
      # The stamp has to read as the hour the agent saw, not UTC.
      it 'renders the stamp in the account timezone' do
        account.update!(reporting_timezone: 'America/Sao_Paulo')
        communication.update!(sent_at: Time.zone.parse('2026-08-26 14:01 UTC'))

        expect(body_of(mail)).to include('26/08/2026 11:01')
      end

      it 'falls back cleanly when the account has none' do
        communication.update!(sent_at: Time.zone.parse('2026-08-26 14:01 UTC'))

        expect(body_of(mail)).to include('26/08/2026 14:01')
      end
    end

    describe 'the sender signature' do
      it 'appends it when the sender has one' do
        user.update!(message_signature: 'Maria Suporte | Duesoft')

        expect(body_of(mail)).to include('Maria Suporte | Duesoft')
      end

      # No empty block when there is nothing to sign with.
      it 'leaves nothing behind when there is none' do
        user.update!(message_signature: nil)

        expect(body_of(mail)).to include('Duesoft Sistemas')
        expect(body_of(mail)).not_to match(/<p>\s*<\/p>/)
      end
    end

    describe 'a ticket without an Empresa' do
      let(:contact) do
        create(:contact, account: account, company: nil,
                         name: 'João Vitor', email: 'joao@eletrosul.com')
      end
      let(:ticket) do
        create(:ticket, account: account, ticket_column: column, team: team,
                        company: nil, contact: contact, title: 'Erro na emissão da nota')
      end

      # "da empresa " with nothing after it reads as a bug.
      it 'greets without inventing an empty company' do
        expect(body_of(mail)).to include('Olá João Vitor.')
        expect(body_of(mail)).not_to include('da empresa .')
      end

      it 'still identifies the ticket, without empty brackets' do
        expect(body_of(mail)).to include("##{ticket.display_id} - [João Vitor] | [Erro na emissão da nota]")
      end
    end
  end

  # The two events are separate messages: sending correspondence and later
  # closing the ticket produces two different e-mails.
  describe 'the closing notice' do
    it 'is a different action from ordinary correspondence' do
      closing = described_class.with(account: account).closing_communication(communication)
      ordinary = described_class.with(account: account).customer_message(communication)

      expect(body_of(closing)).not_to eq(body_of(ordinary))
    end
  end
end
