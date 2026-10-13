# Expande uma lista de CalendarEvent (alguns simples, alguns series
# recorrentes) numa lista PLANA de ocorrencias dentro de [since, until_at] -
# cada ocorrencia e' um objeto com a MESMA superficie de metodos que
# `_calendar_event.json.jbuilder` ja espera de `resource`, para que o
# jbuilder renderize ocorrencias virtuais sem uma view paralela.
class CalendarEvents::OccurrenceExpansionService
  pattr_initialize [:scope!, :since!, :until_at!]

  # Guarda-chuva contra uma serie "nunca termina" dentro de uma janela
  # absurdamente grande - nenhuma tela hoje pede mais que algumas semanas de
  # uma vez, isto so existe para nunca deixar o servidor preso num loop.
  MAX_OCCURRENCES_PER_SERIES = 500

  def perform
    scope.includes(
      :attendees, :tickets, :created_by,
      occurrence_exceptions: { replacement_event: %i[attendees tickets created_by] }
    ).flat_map { |event| event.recurring? ? expand(event) : plain_occurrence(event) }
         .compact
  end

  private

  attr_reader :scope, :since, :until_at

  def plain_occurrence(event)
    return [] unless event.start_at <= until_at && event.end_at >= since

    [event]
  end

  def expand(event)
    exceptions_by_date = event.occurrence_exceptions.index_by(&:occurrence_date)
    duration = event.end_at - event.start_at

    dates_for(event).filter_map do |date|
      exception = exceptions_by_date[date]
      next if exception&.cancelled?

      if exception&.modified?
        replacement = exception.replacement_event
        Occurrence.new(
          id: event.id, occurrence_date: date, start_at: replacement.start_at, end_at: replacement.end_at,
          series: event, display_source: replacement
        )
      else
        occurrence_start = event.start_at.change(year: date.year, month: date.month, day: date.day)
        Occurrence.new(
          id: event.id, occurrence_date: date, start_at: occurrence_start, end_at: occurrence_start + duration,
          series: event, display_source: event
        )
      end
    end
  end

  # Gera as datas-base da serie dentro da janela, SEM materializar a serie
  # inteira quando ela "nunca termina" - anda data a data a partir do
  # start_at, incrementando por frequencia/intervalo, e para no `until_at`,
  # no `recurrence_end_at`, no `recurrence_count` ou no teto de seguranca, o
  # que vier primeiro.
  def dates_for(event)
    dates = []
    date = event.start_at.to_date
    occurrence_index = 0

    loop do
      break if series_exhausted?(event, date, occurrence_index)

      dates << date if date >= since.to_date
      occurrence_index += 1
      date = next_date(event, occurrence_index)
    end

    dates
  end

  def series_exhausted?(event, date, occurrence_index)
    return true if date > until_at.to_date
    return true if event.recurrence_end_at.present? && date > event.recurrence_end_at.to_date
    return true if event.recurrence_count.present? && occurrence_index >= event.recurrence_count

    occurrence_index >= MAX_OCCURRENCES_PER_SERIES
  end

  def next_date(event, occurrence_index)
    anchor = event.start_at.to_date
    interval = event.recurrence_interval

    case event.recurrence_frequency
    when 'daily'   then anchor + (interval * occurrence_index).days
    when 'weekly'  then anchor + (interval * occurrence_index).weeks
    when 'monthly' then clamp_to_month(anchor, interval * occurrence_index)
    when 'yearly'  then clamp_to_month(anchor, interval * occurrence_index * 12)
    end
  end

  # Ancora no MESMO dia-do-mes do start_at: se o mes de destino for mais
  # curto (ex.: dia 31 em fevereiro), usa o ultimo dia daquele mes.
  def clamp_to_month(anchor_date, months_to_add)
    target_month_start = anchor_date.beginning_of_month + months_to_add.months
    day = [anchor_date.day, target_month_start.end_of_month.day].min
    target_month_start.change(day: day)
  end

  # PORO - nao e' um ActiveRecord fingindo ser model, so' precisa responder
  # o que o jbuilder pede. Um Struct com delegacao explicita e' mais rapido
  # que OpenStruct e autodocumenta exatamente o contrato esperado.
  #
  # `id`/`recurring_series_id` SEMPRE vem da SERIE (`series`), nunca de
  # `display_source` - e' o que garante que editar/excluir qualquer
  # ocorrencia (gerada ou substituida por excecao) aponta de volta pro
  # registro mestre certo. Os campos de exibicao vem de `display_source`:
  # a propria serie quando a data nao tem excecao, ou o `replacement_event`
  # quando a ocorrencia foi editada individualmente.
  Occurrence = Struct.new(:id, :occurrence_date, :start_at, :end_at, :series, :display_source, keyword_init: true) do
    def title = display_source.title
    def description = display_source.description
    def all_day = display_source.all_day
    def location = display_source.location
    def color = display_source.color
    def event_type = display_source.event_type
    def team_id = display_source.team_id
    def created_by_id = display_source.created_by_id
    def created_by = display_source.created_by
    def attendees = display_source.attendees
    def tickets = display_source.tickets
    def created_at = display_source.created_at
    def updated_at = display_source.updated_at
    def is_recurring = true # rubocop:disable Naming/PredicateName -- espelha o nome que o JSON expõe
    def recurring_series_id = series.id
  end
end
