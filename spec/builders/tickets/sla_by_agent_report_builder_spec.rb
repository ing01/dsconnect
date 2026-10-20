require 'rails_helper'

# O relatorio de SLA por agente e por Cliente - junto (kind: 'all') ou
# separado por tipo de relogio (atendimento/estagio/solucao), como pedido.
RSpec.describe Tickets::SlaByAgentReportBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:ticket) do
    create(:ticket, account: account, team: team, assignee: agente,
                    ticket_column: create(:ticket_column, team: team, position: 0))
  end

  def relogio(attrs = {})
    TicketAppliedSla.create!(
      { account: account, ticket: ticket, kind: :response, status: :active,
        started_at: 2.hours.ago, due_at: 1.hour.from_now, threshold: 3600 }.merge(attrs)
    )
  end

  def relatorio(params = {})
    described_class.new(account: account, params: ActionController::Parameters.new(params)).perform
  end

  it 'counts a clock that already hit, inside its threshold' do
    relogio(status: :hit, started_at: 2.hours.ago, completed_at: 1.hour.ago)

    totals = relatorio[:totals]
    expect(totals).to include(clocks: 1, hit: 1, missed: 0, active: 0, hit_rate: 100.0)
  end

  it 'counts a clock that missed and already closed' do
    relogio(status: :missed, started_at: 3.hours.ago, due_at: 2.hours.ago, completed_at: 1.hour.ago)

    totals = relatorio[:totals]
    expect(totals).to include(clocks: 1, hit: 0, missed: 1, hit_rate: 0.0)
  end

  # O ponto central do pedido: `mark_missed!` marca vencido SEM fechar o
  # relogio - completed_at continua nulo. Contar isso como "active" (ainda
  # correndo bem) esconderia exatamente o que o relatorio existe para mostrar.
  it 'counts a clock marked missed but still open (not completed) as missed, not active' do
    relogio(status: :missed, started_at: 3.hours.ago, due_at: 1.hour.ago, completed_at: nil)

    totals = relatorio[:totals]
    expect(totals[:missed]).to eq(1)
    expect(totals[:active]).to eq(0)
  end

  it 'only counts genuinely still-running clocks as active' do
    relogio(status: :active, started_at: 1.hour.ago, due_at: 1.hour.from_now)

    expect(relatorio[:totals][:active]).to eq(1)
  end

  it 'measures the actual time spent only for clocks that already closed' do
    relogio(status: :hit, started_at: 3.hours.ago, completed_at: 1.hour.ago)
    relogio(status: :active, started_at: 1.hour.ago, due_at: 1.hour.from_now)

    expect(relatorio[:totals][:actual_hours]).to be_within(0.01).of(2.0)
  end

  # Atraso soma os dois casos de vencido - fechado e ainda aberto - porque os
  # dois ja pesaram no tempo gasto, mesmo sem o relogio ter fechado.
  it 'adds up overrun hours for both a closed miss and a still-open miss' do
    relogio(status: :missed, started_at: 5.hours.ago, due_at: 3.hours.ago, completed_at: 2.hours.ago)

    travel_to(1.hour.from_now) do
      relogio(status: :missed, started_at: 2.hours.ago, due_at: 30.minutes.ago, completed_at: nil)

      expect(relatorio[:totals][:overrun_hours]).to be_within(0.01).of(1.5)
    end
  end

  it 'breaks down by kind, keeping the three kinds even when empty' do
    relogio(kind: :response, status: :hit, completed_at: 1.hour.ago)

    kinds = relatorio[:by_kind].map { |row| row[:kind] }
    expect(kinds).to contain_exactly('response', 'stage', 'resolution')
    expect(relatorio[:by_kind].find { |row| row[:kind] == 'response' }[:hit]).to eq(1)
    expect(relatorio[:by_kind].find { |row| row[:kind] == 'stage' }[:clocks]).to eq(0)
  end

  # O pedido: "deve ser possivel ver junto ou separado" - uma linha por tipo
  # MAIS uma linha "all" somando os tres, por agente.
  it 'reports by user both split by kind and combined ("all")' do
    relogio(kind: :response, status: :hit, completed_at: 1.hour.ago)
    relogio(kind: :resolution, status: :missed, due_at: 1.hour.ago, completed_at: nil)

    linhas = relatorio[:by_user].select { |row| row[:user_id] == agente.id }
    por_tipo = linhas.index_by { |row| row[:kind] }

    expect(por_tipo['response'][:hit]).to eq(1)
    expect(por_tipo['resolution'][:missed]).to eq(1)
    expect(por_tipo['all'][:clocks]).to eq(2)
  end

  it 'credits the clock to the ticket current assignee' do
    outro_agente = create(:user, account: account, role: :agent)
    relogio(status: :hit, completed_at: 1.hour.ago)
    ticket.update!(assignee: outro_agente)

    linhas = relatorio[:by_user].map { |row| row[:user_id] }.uniq
    expect(linhas).to eq([outro_agente.id])
  end

  describe 'by_company' do
    it 'breaks down by the ticket client, split by kind and combined' do
      cliente = create(:company, account: account)
      ticket.update!(company: cliente)
      relogio(kind: :response, status: :hit, completed_at: 1.hour.ago)

      linhas = relatorio[:by_company].select { |row| row[:company_id] == cliente.id }
      expect(linhas.find { |row| row[:kind] == 'response' }[:hit]).to eq(1)
      expect(linhas.find { |row| row[:kind] == 'all' }[:clocks]).to eq(1)
    end

    it 'narrows everything to one client when filtered' do
      cliente_a = create(:company, account: account)
      cliente_b = create(:company, account: account)
      outro_ticket = create(:ticket, account: account, team: team, assignee: agente,
                                     ticket_column: create(:ticket_column, team: team, position: 0), company: cliente_b)
      ticket.update!(company: cliente_a)
      relogio(status: :hit, completed_at: 1.hour.ago)
      TicketAppliedSla.create!(account: account, ticket: outro_ticket, kind: :response, status: :hit,
                               started_at: 2.hours.ago, due_at: 1.hour.from_now, completed_at: 1.hour.ago, threshold: 3600)

      expect(relatorio(company_id: cliente_a.id)[:totals][:clocks]).to eq(1)
    end
  end

  it 'narrows to a single kind when filtered' do
    relogio(kind: :response, status: :hit, completed_at: 1.hour.ago)
    relogio(kind: :resolution, status: :hit, completed_at: 1.hour.ago)

    expect(relatorio(kind: 'resolution')[:totals][:clocks]).to eq(1)
  end

  it 'narrows to the chosen team' do
    outra_mesa = create(:team, account: account)
    outro_ticket = create(:ticket, account: account, team: outra_mesa, assignee: agente,
                                   ticket_column: create(:ticket_column, team: outra_mesa, position: 0))
    relogio(status: :hit, completed_at: 1.hour.ago)
    TicketAppliedSla.create!(account: account, ticket: outro_ticket, kind: :response, status: :hit,
                             started_at: 2.hours.ago, due_at: 1.hour.from_now, completed_at: 1.hour.ago, threshold: 3600)

    expect(relatorio(team_id: team.id)[:totals][:clocks]).to eq(1)
  end
end
