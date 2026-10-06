require 'rails_helper'

RSpec.describe CalendarEvents::DestroyOccurrenceService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:serie) do
    create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 1,
                            start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))
  end

  def excluir(scope:, occurrence_date: nil)
    described_class.new(calendar_event: serie, scope: scope, occurrence_date: occurrence_date).perform
  end

  describe 'escopo occurrence' do
    it 'cria uma excecao cancelled so para aquela data' do
      excluir(scope: 'occurrence', occurrence_date: Date.new(2026, 11, 9))

      excecao = serie.occurrence_exceptions.find_by(occurrence_date: Date.new(2026, 11, 9))
      expect(excecao).to be_cancelled
      expect(serie.reload).to be_persisted
    end

    it 'substitui uma excecao modified existente por uma cancelled, destruindo o replacement antigo' do
      substituto = create(:calendar_event, account: account, team: team)
      excecao = create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 9),
                                                             kind: :modified, replacement_event: substituto)

      excluir(scope: 'occurrence', occurrence_date: Date.new(2026, 11, 9))

      expect(excecao.reload).to be_cancelled
      expect(excecao.replacement_event_id).to be_nil
      expect(CalendarEvent.exists?(substituto.id)).to be(false)
    end
  end

  describe 'escopo future' do
    it 'termina a serie um dia antes da data e destroi excecoes a partir dela' do
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 23), kind: :cancelled)
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 2), kind: :cancelled)

      excluir(scope: 'future', occurrence_date: Date.new(2026, 11, 16))

      expect(serie.reload.recurrence_end_at.to_date).to eq(Date.new(2026, 11, 15))
      expect(serie.occurrence_exceptions.pluck(:occurrence_date)).to eq([Date.new(2026, 11, 2)])
    end
  end

  describe 'escopo series' do
    it 'destroi a serie inteira, em cascata com as excecoes e seus replacement_events' do
      substituto = create(:calendar_event, account: account, team: team)
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 9), kind: :modified,
                                                   replacement_event: substituto)

      excluir(scope: 'series')

      expect(CalendarEvent.exists?(serie.id)).to be(false)
      expect(CalendarEvent.exists?(substituto.id)).to be(false)
    end
  end
end
