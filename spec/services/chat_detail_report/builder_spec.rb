require 'rails_helper'

# O relatorio "Chat detalhado": uma linha por conversa e o resumo do periodo.
RSpec.describe ChatDetailReport::Builder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'João Lucas') }
  let(:company) { create(:company, account: account, name: 'Pesque Pague Ribeiro') }
  let(:contact) { create(:contact, account: account, company: company, name: 'Tonny Milan', phone_number: '+5518997762610') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:params) { {} }
  let(:builder) { described_class.new(account: account, params: params) }

  let!(:attended) do
    conv = conversation(created_at: Time.zone.parse('2026-11-02 12:43'), assignee: agent, status: :resolved,
                        first_reply_created_at: Time.zone.parse('2026-11-03 08:07'))
    assign_message(conv, at: Time.zone.parse('2026-11-03 08:05'))
    conv.update_columns(status_changed_at: Time.zone.parse('2026-11-03 08:28')) # rubocop:disable Rails/SkipsModelValidations
    conv
  end

  let!(:cancelled) do
    conv = conversation(created_at: Time.zone.parse('2026-11-01 09:56'), status: :resolved)
    conv.update_columns(status_changed_at: Time.zone.parse('2026-11-01 09:56')) # rubocop:disable Rails/SkipsModelValidations
    conv
  end

  def conversation(created_at:, **attrs)
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          created_at: created_at, **attrs)
  end

  def assign_message(conversation, at:)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :activity,
                     content: "Atribuído a #{agent.name} por Sistema", created_at: at)
  end

  def row(conv)
    builder.each_entry.find { |entry| entry.row[:id] == conv.display_id }.row
  end

  it 'has the 22 columns of the model sheet, in order' do
    expect(described_class.headers).to eq(
      ['ID', 'Cliente', 'Origem', 'Iniciado por', 'Iniciado em', 'Assumido em', 'Primeira mensagem enviada',
       'Atualizado em', 'Finalizado em', 'Duração', 'Tempo de espera', 'Responsável', 'Grupo de atendente',
       'Departamento', 'Conversado com', 'Status', 'Telefone', 'Avaliação', 'Catálogo de serviços',
       'Área do catálogo', 'Item do Catálogo', 'Ticket']
    )
  end

  it 'fills the attended chat with who, when, wait and duration', :aggregate_failures do
    data = row(attended)

    expect(data[:client]).to eq('Pesque Pague Ribeiro')
    expect(data[:contact]).to eq('Tonny Milan')
    expect(data[:phone]).to eq('5518997762610')
    expect(data[:assignee]).to eq('João Lucas')
    expect(data[:status]).to eq('Fechado')
    expect(data[:started_at]).to eq('02/11/2026 12:43')
    expect(data[:assumed_at]).to eq('03/11/2026 08:05')
    expect(data[:first_message_at]).to eq('03/11/2026 08:07')
    expect(data[:finished_at]).to eq('03/11/2026 08:28')
    # espera: 12:43 -> 08:05 do dia seguinte; duracao: 08:05 -> 08:28
    expect(data[:wait]).to eq('19:22:00')
    expect(data[:duration]).to eq('00:23:00')
  end

  it 'marks a chat finished without anyone taking it as cancelled', :aggregate_failures do
    data = row(cancelled)

    expect(data[:assumed_at]).to eq('Finalizado sem atendimento')
    expect(data[:assignee]).to be_nil
    expect(data[:duration]).to eq('00:00:00')
    expect(data[:wait]).to eq('00:00:00')
  end

  it 'leaves what is not filled in empty' do
    data = row(attended)

    expect(data[:group]).to be_nil
    expect(data[:department]).to be_nil
    expect(data[:rating]).to be_nil
    expect(data[:ticket]).to be_nil
    expect(data[:catalog]).to be_nil
  end

  it 'shows the linked ticket and its catalog classification' do
    team = create(:team, account: account)
    column = create(:ticket_column, team: team)
    category = create(:ticket_category, team: team)
    ticket = create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category)
    TicketConversation.create!(account_id: account.id, ticket: ticket, conversation: attended)

    expect(row(attended)[:ticket]).to eq(ticket.display_id.to_s)
  end

  it 'writes who started the chat from the first message' do
    create(:message, account: account, inbox: inbox, conversation: attended, message_type: :incoming, content: 'Oi')

    expect(row(attended)[:started_by]).to eq('Solicitante')
  end

  describe '#summary' do
    it 'counts attended, cancelled, contacts and averages', :aggregate_failures do
      summary = builder.summary

      expect(summary[:attended]).to eq(1)
      expect(summary[:cancelled]).to eq(1)
      expect(summary[:contacts]).to eq(1)
      expect(summary[:first_contact]).to eq(1)
      expect(summary[:average_duration]).to eq('00:23:00')
      expect(summary[:average_wait]).to eq('19:22:00')
      expect(summary[:total_time]).to eq('00:23:00')
    end

    it 'shows hours above 24 without wrapping' do
      conversation(created_at: Time.zone.parse('2026-10-01 08:00'), assignee: agent, status: :resolved)
      long = Conversation.order(:id).last
      assign_message(long, at: Time.zone.parse('2026-10-01 08:00'))
      long.update_columns(status_changed_at: Time.zone.parse('2026-10-04 12:30:15')) # rubocop:disable Rails/SkipsModelValidations

      expect(described_class.new(account: account, params: { from: '2026-10-01', to: '2026-10-31' }).summary[:total_time])
        .to eq('76:30:15')
    end
  end

  describe 'filters' do
    it 'limits by period (the day is included whole)' do
      builder = described_class.new(account: account, params: { from: '2026-11-02', to: '2026-11-02' })

      expect(builder.each_entry.map { |entry| entry.row[:id] }).to eq([attended.display_id])
    end

    it 'limits by responsible and by status' do
      by_agent = described_class.new(account: account, params: { assignee_id: agent.id })
      by_status = described_class.new(account: account, params: { status: 'open' })

      expect(by_agent.total).to eq(1)
      expect(by_status.total).to eq(0)
    end

    it 'limits by the company of the contact' do
      other = create(:company, account: account)

      expect(described_class.new(account: account, params: { company_id: other.id }).total).to eq(0)
      expect(described_class.new(account: account, params: { company_id: company.id }).total).to eq(2)
    end

    it 'ignores conversations of another account' do
      create(:conversation)

      expect(builder.total).to eq(2)
    end
  end

  describe '#page' do
    it 'returns one page of rows and the summary of the whole period' do
      result = builder.page(page: 1, per_page: 1)

      expect(result[:rows].size).to eq(1)
      expect(result[:total]).to eq(2)
      expect(result[:summary][:cancelled]).to eq(1)
    end
  end

  it 'refuses a period above the limit, asking to narrow it' do
    stub_const("#{described_class}::MAX_ROWS", 1)

    expect { builder.each_entry.to_a }.to raise_error(described_class::TooManyRows)
  end
end
