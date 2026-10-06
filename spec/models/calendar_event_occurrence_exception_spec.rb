require 'rails_helper'

RSpec.describe CalendarEventOccurrenceException do
  describe 'unicidade de occurrence_date por serie' do
    it 'recusa, na validacao, uma segunda excecao na mesma data' do
      serie = create(:calendar_event, :weekly)
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 2))

      segunda = build(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 2))

      expect(segunda).to be_invalid
      expect(segunda.errors[:occurrence_date]).not_to be_empty
    end

    # A trava de verdade e' o INDICE UNICO do banco, nao so' a validacao -
    # mesmo padrao usado em MonthlySatisfactionSurvey.
    it 'recusa no banco, por tras da validacao' do
      serie = create(:calendar_event, :weekly)
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 2))

      segunda = build(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 2))

      expect { segunda.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'replacement_event so quando modified' do
    it 'exige replacement_event quando o tipo e modified' do
      serie = create(:calendar_event, :weekly)
      excecao = build(:calendar_event_occurrence_exception, calendar_event: serie, kind: :modified, replacement_event: nil)

      expect(excecao).to be_invalid
      expect(excecao.errors[:replacement_event]).not_to be_empty
    end

    it 'recusa replacement_event quando o tipo e cancelled' do
      serie = create(:calendar_event, :weekly)
      substituto = create(:calendar_event, account: serie.account, team: serie.team)
      excecao = build(:calendar_event_occurrence_exception, calendar_event: serie, kind: :cancelled, replacement_event: substituto)

      expect(excecao).to be_invalid
      expect(excecao.errors[:replacement_event]).not_to be_empty
    end
  end
end
