require 'rails_helper'

RSpec.describe 'Calendar events API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }

  def cabecalho(user = admin)
    user.create_new_auth_token
  end

  def listar(params = {})
    get "/api/v1/accounts/#{account.id}/calendar_events", params: params, headers: cabecalho, as: :json
  end

  def atualizar(evento, body)
    patch "/api/v1/accounts/#{account.id}/calendar_events/#{evento.id}", params: body, headers: cabecalho, as: :json
  end

  def excluir(evento, params = {})
    delete "/api/v1/accounts/#{account.id}/calendar_events/#{evento.id}", params: params, headers: cabecalho, as: :json
  end

  describe 'GET index' do
    # Pin de compatibilidade: sem janela, continua devolvendo as linhas cruas,
    # exatamente como antes da recorrencia existir.
    it 'without a window, returns raw rows exactly as before' do
      evento = create(:calendar_event, account: account, team: team)

      listar(team_id: team.id)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].map { |item| item['id'] }).to eq([evento.id])
    end

    it 'with a window, expands a recurring series into its occurrences' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))

      listar(team_id: team.id, since: '2026-11-01T00:00:00Z', until: '2026-11-30T23:59:59Z')

      datas = response.parsed_body['payload'].map { |item| item['occurrence_date'] }
      expect(datas).to eq(%w[2026-11-02 2026-11-09 2026-11-16 2026-11-23 2026-11-30])
      expect(response.parsed_body['payload'].map { |item| item['id'] }.uniq).to eq([serie.id])
    end

    it 'includes a plain event inside the same window, unaffected' do
      create(:calendar_event, account: account, team: team, start_at: Time.zone.parse('2026-11-05 10:00'),
                              end_at: Time.zone.parse('2026-11-05 11:00'))

      listar(team_id: team.id, since: '2026-11-01T00:00:00Z', until: '2026-11-30T23:59:59Z')

      expect(response.parsed_body['payload'].size).to eq(1)
    end
  end

  describe 'PATCH update' do
    # Pin de compatibilidade: sem `scope`, um evento simples se comporta
    # exatamente como antes.
    it 'without scope, updates a plain event exactly as before' do
      evento = create(:calendar_event, account: account, team: team)

      atualizar(evento, calendar_event: { title: 'Novo titulo' })

      expect(response).to have_http_status(:success)
      expect(evento.reload.title).to eq('Novo titulo')
      expect(CalendarEventOccurrenceException.count).to eq(0)
    end

    it 'with scope=occurrence, only creates an exception for that date' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))

      atualizar(serie, calendar_event: { title: 'Reuniao adiada' }, scope: 'occurrence', occurrence_date: '2026-11-09')

      expect(response).to have_http_status(:success)
      expect(serie.reload.title).not_to eq('Reuniao adiada')
      expect(serie.occurrence_exceptions.find_by(occurrence_date: Date.new(2026, 11, 9))).to be_modified
    end

    it 'with scope=future, forks the series and returns the new one' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))

      atualizar(serie, calendar_event: { title: 'Nova serie' }, scope: 'future', occurrence_date: '2026-11-16')

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).not_to eq(serie.id)
      expect(serie.reload.recurrence_end_at.to_date).to eq(Date.new(2026, 11, 15))
    end

    it 'with scope=series, updates the master row directly' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))

      atualizar(serie, calendar_event: { title: 'Toda a serie' }, scope: 'series')

      expect(response).to have_http_status(:success)
      expect(serie.reload.title).to eq('Toda a serie')
    end

    it 'ignores scope for a non-recurring event' do
      evento = create(:calendar_event, account: account, team: team)

      atualizar(evento, calendar_event: { title: 'Teste' }, scope: 'future', occurrence_date: '2026-11-09')

      expect(response).to have_http_status(:success)
      expect(evento.reload.title).to eq('Teste')
      expect(CalendarEventOccurrenceException.count).to eq(0)
    end
  end

  describe 'DELETE destroy' do
    it 'without scope, destroys a plain event exactly as before' do
      evento = create(:calendar_event, account: account, team: team)

      excluir(evento)

      expect(response).to have_http_status(:success)
      expect(CalendarEvent.exists?(evento.id)).to be(false)
    end

    it 'with scope=occurrence, keeps the series and only cancels that date' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))

      excluir(serie, scope: 'occurrence', occurrence_date: '2026-11-09')

      expect(response).to have_http_status(:success)
      expect(CalendarEvent.exists?(serie.id)).to be(true)
      expect(serie.occurrence_exceptions.find_by(occurrence_date: Date.new(2026, 11, 9))).to be_cancelled
    end

    it 'with scope=series, destroys the whole series' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))

      excluir(serie, scope: 'series')

      expect(response).to have_http_status(:success)
      expect(CalendarEvent.exists?(serie.id)).to be(false)
    end
  end
end
