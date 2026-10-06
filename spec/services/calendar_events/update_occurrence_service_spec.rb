require 'rails_helper'

RSpec.describe CalendarEvents::UpdateOccurrenceService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:serie) do
    create(:calendar_event, account: account, team: team, title: 'Reuniao semanal', recurrence_frequency: :weekly,
                            recurrence_interval: 1, start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))
  end

  def editar(scope:, occurrence_date: nil, attributes: {})
    described_class.new(calendar_event: serie, scope: scope, occurrence_date: occurrence_date, attributes: attributes).perform
  end

  describe 'escopo occurrence' do
    it 'cria uma excecao modified so para aquela data, sem tocar na serie' do
      resultado = editar(
        scope: 'occurrence', occurrence_date: Date.new(2026, 11, 9),
        attributes: { title: 'Reuniao adiada', start_at: Time.zone.parse('2026-11-09 15:00'), end_at: Time.zone.parse('2026-11-09 15:30') }
      )

      excecao = serie.occurrence_exceptions.find_by(occurrence_date: Date.new(2026, 11, 9))
      expect(excecao).to be_modified
      expect(excecao.replacement_event).to eq(resultado)
      expect(resultado.title).to eq('Reuniao adiada')
      expect(serie.reload.title).to eq('Reuniao semanal')
    end

    it 'e idempotente ao editar a mesma data de novo' do
      editar(scope: 'occurrence', occurrence_date: Date.new(2026, 11, 9), attributes: { title: 'Primeira edicao' })

      expect do
        editar(scope: 'occurrence', occurrence_date: Date.new(2026, 11, 9), attributes: { title: 'Segunda edicao' })
      end.not_to change(CalendarEventOccurrenceException, :count)

      excecao = serie.occurrence_exceptions.find_by(occurrence_date: Date.new(2026, 11, 9))
      expect(excecao.replacement_event.title).to eq('Segunda edicao')
    end
  end

  describe 'escopo future' do
    it 'termina a serie antiga um dia antes e cria uma serie nova a partir da ocorrencia' do
      nova_serie = editar(scope: 'future', occurrence_date: Date.new(2026, 11, 16), attributes: { title: 'Reuniao (novo horario)' })

      expect(serie.reload.recurrence_end_at.to_date).to eq(Date.new(2026, 11, 15))
      expect(nova_serie.recurrence_frequency).to eq('weekly')
      expect(nova_serie.recurrence_parent_id).to eq(serie.id)
      expect(nova_serie.title).to eq('Reuniao (novo horario)')
      expect(nova_serie.start_at.to_date).to eq(Date.new(2026, 11, 16))
    end

    it 'reparenta excecoes estritamente depois da data para a serie nova' do
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 23), kind: :cancelled)

      nova_serie = editar(scope: 'future', occurrence_date: Date.new(2026, 11, 16), attributes: { title: 'Nova' })

      expect(serie.occurrence_exceptions.where(occurrence_date: Date.new(2026, 11, 23))).to be_empty
      expect(nova_serie.occurrence_exceptions.where(occurrence_date: Date.new(2026, 11, 23))).to exist
    end

    it 'destroi (em vez de reparentar) uma excecao exatamente na data da bifurcacao' do
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 16), kind: :cancelled)

      nova_serie = editar(scope: 'future', occurrence_date: Date.new(2026, 11, 16), attributes: { title: 'Nova' })

      expect(CalendarEventOccurrenceException.where(occurrence_date: Date.new(2026, 11, 16))).to be_empty
      expect(nova_serie.occurrence_exceptions).to be_empty
    end
  end

  describe 'escopo series' do
    it 'atualiza a linha mestre direto, inclusive a regra de recorrencia' do
      resultado = editar(scope: 'series', attributes: { title: 'Reuniao quinzenal', recurrence_interval: 2 })

      expect(resultado).to eq(serie)
      expect(serie.reload.title).to eq('Reuniao quinzenal')
      expect(serie.recurrence_interval).to eq(2)
    end
  end
end
