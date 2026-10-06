require 'rails_helper'

RSpec.describe CalendarEvents::OccurrenceExpansionService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }

  def expandir(serie, desde:, ate:)
    described_class.new(scope: CalendarEvent.where(id: serie.id), since: desde, until_at: ate).perform
  end

  describe 'evento simples' do
    it 'passa direto quando sobrepoe a janela' do
      evento = create(:calendar_event, account: account, team: team,
                                       start_at: Time.zone.parse('2026-11-05 10:00'), end_at: Time.zone.parse('2026-11-05 11:00'))

      resultado = expandir(evento, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-11-30'))

      expect(resultado.map(&:id)).to eq([evento.id])
    end

    it 'nao aparece quando esta fora da janela' do
      evento = create(:calendar_event, account: account, team: team,
                                       start_at: Time.zone.parse('2026-12-05 10:00'), end_at: Time.zone.parse('2026-12-05 11:00'))

      resultado = expandir(evento, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-11-30'))

      expect(resultado).to be_empty
    end
  end

  describe 'serie diaria' do
    it 'gera uma ocorrencia por dia dentro da janela' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :daily, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-01 09:00'), end_at: Time.zone.parse('2026-11-01 09:30'))

      resultado = expandir(serie, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-11-05 23:59'))

      expect(resultado.map(&:occurrence_date)).to eq((Date.new(2026, 11, 1)..Date.new(2026, 11, 5)).to_a)
    end
  end

  describe 'serie semanal com intervalo' do
    it 'respeita "a cada N semanas"' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :weekly, recurrence_interval: 2,
                                      start_at: Time.zone.parse('2026-11-02 09:00'), end_at: Time.zone.parse('2026-11-02 09:30'))

      resultado = expandir(serie, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-12-15'))

      expect(resultado.map(&:occurrence_date)).to eq([Date.new(2026, 11, 2), Date.new(2026, 11, 16), Date.new(2026, 11, 30), Date.new(2026, 12, 14)])
    end
  end

  describe 'serie mensal' do
    it 'ancora no mesmo dia do mes' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :monthly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-15 09:00'), end_at: Time.zone.parse('2026-11-15 09:30'))

      resultado = expandir(serie, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2027-02-28'))

      expect(resultado.map(&:occurrence_date)).to eq([Date.new(2026, 11, 15), Date.new(2026, 12, 15), Date.new(2027, 1, 15), Date.new(2027, 2, 15)])
    end

    # Dia 31 nao existe em fevereiro - cai no ultimo dia daquele mes.
    it 'cai no ultimo dia do mes quando o mes de destino e mais curto' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :monthly, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-12-31 09:00'), end_at: Time.zone.parse('2026-12-31 09:30'))

      resultado = expandir(serie, desde: Time.zone.parse('2026-12-01'), ate: Time.zone.parse('2027-02-28'))

      expect(resultado.map(&:occurrence_date)).to eq([Date.new(2026, 12, 31), Date.new(2027, 1, 31), Date.new(2027, 2, 28)])
    end
  end

  describe 'termino da serie' do
    it 'corta em recurrence_end_at' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :daily, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-01 09:00'), end_at: Time.zone.parse('2026-11-01 09:30'),
                                      recurrence_end_at: Time.zone.parse('2026-11-03'))

      resultado = expandir(serie, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-11-10'))

      expect(resultado.map(&:occurrence_date)).to eq([Date.new(2026, 11, 1), Date.new(2026, 11, 2), Date.new(2026, 11, 3)])
    end

    it 'corta depois de recurrence_count ocorrencias' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :daily, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-01 09:00'), end_at: Time.zone.parse('2026-11-01 09:30'),
                                      recurrence_count: 3)

      resultado = expandir(serie, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-11-10'))

      expect(resultado.size).to eq(3)
    end

    it 'nunca termina quando nenhuma das duas condicoes esta presente' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :daily, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-01 09:00'), end_at: Time.zone.parse('2026-11-01 09:30'))

      resultado = expandir(serie, desde: Time.zone.parse('2027-06-01'), ate: Time.zone.parse('2027-06-03'))

      expect(resultado.map(&:occurrence_date)).to eq([Date.new(2027, 6, 1), Date.new(2027, 6, 2), Date.new(2027, 6, 3)])
    end
  end

  describe 'excecoes' do
    it 'uma excecao cancelled remove aquela data, sem afetar as outras' do
      serie = create(:calendar_event, account: account, team: team, recurrence_frequency: :daily, recurrence_interval: 1,
                                      start_at: Time.zone.parse('2026-11-01 09:00'), end_at: Time.zone.parse('2026-11-01 09:30'))
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 2), kind: :cancelled)

      resultado = expandir(serie, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-11-03 23:59'))

      expect(resultado.map(&:occurrence_date)).to eq([Date.new(2026, 11, 1), Date.new(2026, 11, 3)])
    end

    it 'uma excecao modified troca os campos exibidos, mas mantem o id da serie' do
      serie = create(:calendar_event, account: account, team: team, title: 'Reuniao semanal', recurrence_frequency: :daily,
                                      recurrence_interval: 1, start_at: Time.zone.parse('2026-11-01 09:00'),
                                      end_at: Time.zone.parse('2026-11-01 09:30'))
      substituto = create(:calendar_event, account: account, team: team, title: 'Reuniao adiada',
                                           start_at: Time.zone.parse('2026-11-02 15:00'), end_at: Time.zone.parse('2026-11-02 15:30'))
      create(:calendar_event_occurrence_exception, calendar_event: serie, occurrence_date: Date.new(2026, 11, 2), kind: :modified,
                                                   replacement_event: substituto)

      resultado = expandir(serie, desde: Time.zone.parse('2026-11-01'), ate: Time.zone.parse('2026-11-02 23:59'))
      ocorrencia_editada = resultado.find { |item| item.occurrence_date == Date.new(2026, 11, 2) }

      expect(ocorrencia_editada.id).to eq(serie.id)
      expect(ocorrencia_editada.title).to eq('Reuniao adiada')
      expect(ocorrencia_editada.start_at).to eq(substituto.start_at)
    end
  end
end
