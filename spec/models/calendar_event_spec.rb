require 'rails_helper'

RSpec.describe CalendarEvent do
  describe 'validacoes basicas' do
    it 'exige titulo, inicio e fim' do
      evento = build(:calendar_event, title: nil, start_at: nil, end_at: nil)

      expect(evento).to be_invalid
      expect(evento.errors[:title]).not_to be_empty
      expect(evento.errors[:start_at]).not_to be_empty
      expect(evento.errors[:end_at]).not_to be_empty
    end

    it 'recusa fim antes do inicio' do
      evento = build(:calendar_event, start_at: Time.zone.now, end_at: 1.hour.ago)

      expect(evento).to be_invalid
      expect(evento.errors[:end_at]).not_to be_empty
    end
  end

  describe 'recurring?' do
    it 'e false para um evento simples' do
      expect(build(:calendar_event).recurring?).to be(false)
    end

    it 'e true para qualquer frequencia diferente de none' do
      expect(build(:calendar_event, :weekly).recurring?).to be(true)
    end
  end

  describe 'regra de recorrencia' do
    it 'exige intervalo quando a frequencia nao e none' do
      evento = build(:calendar_event, recurrence_frequency: :weekly, recurrence_interval: nil)

      expect(evento).to be_invalid
      expect(evento.errors[:recurrence_interval]).not_to be_empty
    end

    it 'recusa intervalo menor que 1' do
      evento = build(:calendar_event, recurrence_frequency: :weekly, recurrence_interval: 0)

      expect(evento).to be_invalid
      expect(evento.errors[:recurrence_interval]).not_to be_empty
    end

    it 'recusa data-fim e quantidade de ocorrencias ao mesmo tempo' do
      evento = build(:calendar_event, :weekly, recurrence_end_at: 1.month.from_now, recurrence_count: 5)

      expect(evento).to be_invalid
      expect(evento.errors[:recurrence_end_at]).not_to be_empty
    end

    it 'permite recorrencia sem data-fim e sem quantidade - nunca termina' do
      evento = build(:calendar_event, :weekly, recurrence_end_at: nil, recurrence_count: nil)

      expect(evento).to be_valid
    end

    it 'zera intervalo/termino quando a frequencia volta a none' do
      evento = build(:calendar_event, :weekly, recurrence_count: 5)

      evento.recurrence_frequency = :single
      evento.valid?

      expect(evento.recurrence_interval).to be_nil
      expect(evento.recurrence_count).to be_nil
    end
  end

  describe 'exclusao em cascata das excecoes' do
    it 'destroi as excecoes e o replacement_event ao destruir a serie' do
      serie = create(:calendar_event, :weekly)
      substituto = create(:calendar_event, account: serie.account, team: serie.team)
      excecao = create(:calendar_event_occurrence_exception, calendar_event: serie, kind: :modified,
                                                             replacement_event: substituto)

      serie.destroy!

      expect(CalendarEventOccurrenceException.exists?(excecao.id)).to be(false)
      expect(described_class.exists?(substituto.id)).to be(false)
    end
  end
end
