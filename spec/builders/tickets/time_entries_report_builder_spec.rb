require 'rails_helper'

# O relatorio de apontamentos por nivel. O que se prova aqui e de onde saem os
# NIVEIS do relatorio: eles seguem o que as Mesas da conta usam, e nao os cinco
# que o sistema sabe guardar - um Nivel 4 zerado numa conta que atende em dois
# seria uma linha sobre nada.
RSpec.describe Tickets::TimeEntriesReportBuilder do
  let(:account) { create(:account) }
  let(:agente) { create(:user, account: account, role: :agent) }

  def mesa(count)
    create(:team, account: account, assignee_levels_enabled: true, assignee_levels_count: count)
  end

  def ticket_da(team)
    create(:ticket, account: account, team: team,
                    ticket_column: create(:ticket_column, team: team, position: 0))
  end

  def relatorio(params = {})
    described_class.new(account: account, params: ActionController::Parameters.new(params)).perform
  end

  it 'reports as many levels as the account uses' do
    mesa(3)

    niveis = relatorio[:by_level].map { |row| row[:level] }

    # O `nil` fecha a lista: reune quem apontou sem ser responsavel do ticket.
    expect(niveis).to eq([1, 2, 3, nil])
  end

  it 'reports two levels when no desk goes further' do
    mesa(2)

    expect(relatorio[:by_level].map { |row| row[:level] }).to eq([1, 2, nil])
  end

  # Filtrado por uma Mesa, os niveis sao os DELA: mostrar o Nivel 3 de outra Mesa
  # dentro do relatorio de uma que atende em dois seria uma linha impossivel.
  it 'narrows the levels to the chosen desk' do
    de_dois = mesa(2)
    mesa(3)

    niveis = relatorio(team_id: de_dois.id)[:by_level].map { |row| row[:level] }
    expect(niveis).to eq([1, 2, nil])
  end

  it 'sums the hours logged at each level' do
    team = mesa(3)
    team.add_members([agente.id])
    team.team_members.find_by(user_id: agente.id).update!(levels: [3])
    ticket = ticket_da(team)
    ticket.update!(assignee_3_id: agente.id)

    ticket.ticket_time_entries.create!(account: account, user: agente, hours: 4,
                                       category: 'desenvolvimento', worked_on: Time.zone.today)

    resultado = relatorio
    expect(resultado[:by_level].find { |row| row[:level] == 3 }[:hours]).to eq(4.0)
    expect(resultado[:totals][:hours]).to eq(4.0)
    expect(resultado[:by_user].find { |row| row[:user_id] == agente.id }[:level]).to eq(3)
  end

  # Uma conta sem Mesa com niveis nao deixa o relatorio sem lista nenhuma.
  it 'falls back to the minimum when no desk uses levels' do
    create(:team, account: account)

    expect(relatorio[:by_level].map { |row| row[:level] }).to eq([1, 2, nil])
  end

  # O corte pedido para a analise de margem: quanto cada Cliente consumiu.
  describe 'by_company' do
    it 'sums the hours logged per client' do
      team = create(:team, account: account)
      cliente_a = create(:company, account: account)
      cliente_b = create(:company, account: account)
      ticket_a = ticket_da(team).tap { |t| t.update!(company: cliente_a) }
      ticket_b = ticket_da(team).tap { |t| t.update!(company: cliente_b) }

      ticket_a.ticket_time_entries.create!(account: account, user: agente, hours: 3,
                                           category: 'desenvolvimento', worked_on: Time.zone.today)
      ticket_b.ticket_time_entries.create!(account: account, user: agente, hours: 1,
                                           category: 'desenvolvimento', worked_on: Time.zone.today)

      resultado = relatorio[:by_company]

      expect(resultado.find { |row| row[:company_id] == cliente_a.id }[:hours]).to eq(3.0)
      expect(resultado.find { |row| row[:company_id] == cliente_b.id }[:hours]).to eq(1.0)
    end

    it 'narrows everything to one client when filtered' do
      team = create(:team, account: account)
      cliente_a = create(:company, account: account)
      cliente_b = create(:company, account: account)
      ticket_a = ticket_da(team).tap { |t| t.update!(company: cliente_a) }
      ticket_b = ticket_da(team).tap { |t| t.update!(company: cliente_b) }

      ticket_a.ticket_time_entries.create!(account: account, user: agente, hours: 3,
                                           category: 'desenvolvimento', worked_on: Time.zone.today)
      ticket_b.ticket_time_entries.create!(account: account, user: agente, hours: 1,
                                           category: 'desenvolvimento', worked_on: Time.zone.today)

      resultado = relatorio(company_id: cliente_a.id)

      expect(resultado[:totals][:hours]).to eq(3.0)
    end
  end
end
