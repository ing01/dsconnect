require 'rails_helper'

RSpec.describe CustomerBriefing::MaterialBuilder do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:company) do
    create(:company, name: 'Acme', domain: 'acme.com', account: account, billing_amount: 987.65,
                     cnpj: '11.222.333/0001-81', classification_level: 4)
  end
  let(:contact) do
    create(:contact, account: account, company: company, name: 'Maria', email: 'maria@acme.com',
                     phone_number: '+5511999998888')
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:column) { create(:ticket_column, team: create(:team, account: account)) }

  before { account.enable_features!(:companies) }

  def material
    sources = CustomerBriefing::Sources.new(conversation: conversation, user: admin)
    described_class.new(sources: sources).perform
  end

  def previous_conversation(of: contact)
    create(:conversation, account: account, inbox: inbox, contact: of)
  end

  def say(item, text, **attributes)
    create(:message, account: account, inbox: item.inbox, conversation: item, content: text, **attributes)
  end

  it 'is empty when there is no history, so the AI is not called' do
    expect(material).to be_nil
  end

  it 'is not made of the open conversation alone' do
    say(conversation, 'Olá')

    expect(material).to be_nil
  end

  it 'includes the open conversation in a single conversation inbox' do
    inbox.update!(lock_to_single_conversation: true)
    say(conversation, 'Erro antigo na mesma conversa')

    expect(material).to include('Conversa atual', 'Cliente: Erro antigo na mesma conversa')
  end

  it 'identifies customer, team and private notes, in reading order' do
    old = previous_conversation
    say(old, 'A nota não emite', message_type: :incoming, created_at: 3.minutes.ago)
    say(old, 'Vou verificar', message_type: :outgoing, created_at: 2.minutes.ago)
    say(old, 'Certificado vencido', message_type: :outgoing, private: true, created_at: 1.minute.ago)

    expect(material).to include(
      "Cliente: A nota não emite\nEquipe: Vou verificar\n[Nota interna] Equipe: Certificado vencido"
    )
  end

  it 'leaves out system activity messages' do
    old = previous_conversation
    say(old, 'oi')
    say(old, 'Conversa atribuída', message_type: :activity)

    expect(material).not_to include('Conversa atribuída')
  end

  it 'includes company, notes, tickets and conversations of colleagues' do
    create(:note, contact: contact, content: 'Prefere ligação')
    create(:ticket, ticket_column: column, company: company, title: 'Rejeição na NFS-e', description: "linha 1\nlinha 2")
    colleague = create(:contact, account: account, company: company, name: 'José')
    say(previous_conversation(of: colleague), 'Estoque divergente')

    expect(material).to include('Empresa: Acme', 'Nível: 4', 'Contato atendido: Maria', 'Prefere ligação',
                                'Rejeição na NFS-e', 'Descrição: linha 1 linha 2',
                                'Conversa de outro contato da mesma empresa', 'José', 'Estoque divergente')
  end

  it 'never sends contact data, documents or contract values' do
    create(:note, contact: contact, content: 'nota')

    expect(material).not_to include('maria@acme.com', '999998888', '11222333000181', '11.222.333', '987')
  end

  it 'does not include conversations the person cannot see' do
    agent = create(:user, account: account, role: :agent)
    say(previous_conversation, 'conteúdo restrito')
    create(:note, contact: contact, content: 'nota')
    sources = CustomerBriefing::Sources.new(conversation: conversation, user: agent)

    expect(described_class.new(sources: sources).perform).not_to include('conteúdo restrito')
  end

  it 'truncates long messages and keeps the whole text within the limit' do
    5.times do |index|
      old = previous_conversation
      20.times { |line| say(old, "c#{index}m#{line} #{'x' * 2000}") }
    end

    text = material

    expect(text.length).to be <= described_class::MAX_CHARS + 500
    expect(text.lines.map(&:length).max).to be <= described_class::MESSAGE_LENGTH + 20
  end

  it 'keeps the most recent messages of a long conversation' do
    old = previous_conversation
    40.times { |index| say(old, "mensagem #{index} fim", created_at: (60 - index).minutes.ago) }

    expect(material).to include('mensagem 39 fim')
    expect(material).not_to include('mensagem 0 fim')
  end

  it 'is the same text while nothing changes' do
    say(previous_conversation, 'oi')

    first = material

    travel 1.hour

    expect(material).to eq(first)
  end
end
